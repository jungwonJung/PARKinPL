import Foundation
import CoreLocation

protocol LocationService {
    func requestLocation() async throws -> CLLocation
    func requestPermission() async -> CLAuthorizationStatus
}

final class LocationServiceImpl: NSObject, LocationService {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var permissionContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var didRetryLocationUnknown = false

    override init() {
        super.init()
        // Core Location APIs should be used on main thread
        DispatchQueue.main.async {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
    }

    func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            // Save continuation immediately
            self.locationContinuation = continuation

            guard CLLocationManager.locationServicesEnabled() else {
                continuation.resume(throwing: LocationError.servicesDisabled)
                self.locationContinuation = nil
                return
            }

            // Check authorization status on main thread to avoid warnings
            DispatchQueue.main.async {
                let status = self.authorizationStatus
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    // Safe to request a one-shot location
                    self.locationManager.requestLocation()

                case .notDetermined:
                    // Wait for permission first, then request location
                    Task { [weak self] in
                        guard let self else { return }
                        let newStatus = await self.requestPermission()
                        switch newStatus {
                        case .authorizedWhenInUse, .authorizedAlways:
                            DispatchQueue.main.async { self.locationManager.requestLocation() }
                        case .denied, .restricted:
                            continuation.resume(throwing: LocationError.permissionDenied)
                            self.locationContinuation = nil
                        default:
                            continuation.resume(throwing: LocationError.unknown)
                            self.locationContinuation = nil
                        }
                    }

                case .denied, .restricted:
                    continuation.resume(throwing: LocationError.permissionDenied)
                    self.locationContinuation = nil

                @unknown default:
                    continuation.resume(throwing: LocationError.unknown)
                    self.locationContinuation = nil
                }
            }
        }
    }

    func requestPermission() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            // Check authorization status on main thread to avoid warnings
            DispatchQueue.main.async {
                let status = self.authorizationStatus
                if status == .notDetermined {
                    // Store continuation to be resumed in delegate callback
                    self.permissionContinuation = continuation
                    self.locationManager.requestWhenInUseAuthorization()
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private var authorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationServiceImpl: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Resume anyone awaiting permission
        let status = authorizationStatus
        permissionContinuation?.resume(returning: status)
        permissionContinuation = nil

        // If location was already requested and we were waiting for auth,
        // auto-trigger a request when authorized.
        if (status == .authorizedWhenInUse || status == .authorizedAlways),
           locationContinuation != nil {
            manager.requestLocation()
        } else if (status == .denied || status == .restricted),
                  let cont = locationContinuation {
            cont.resume(throwing: LocationError.permissionDenied)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        didRetryLocationUnknown = false
        guard let cont = locationContinuation else { return }
        guard let location = locations.last else {
            cont.resume(throwing: LocationError.unknown)
            locationContinuation = nil
            return
        }
        cont.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        
        // Handle the temporary "location unknown" (kCLErrorLocationUnknown, code 0)
        if nsError.domain == kCLErrorDomain as String, 
           nsError.code == CLError.locationUnknown.rawValue,
           didRetryLocationUnknown == false {
            didRetryLocationUnknown = true
            // Retry once after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                manager.requestLocation()
            }
            return
        }

        // After retry, if still failing, provide better error message
        if nsError.domain == kCLErrorDomain as String,
           nsError.code == CLError.locationUnknown.rawValue {
            #if targetEnvironment(simulator)
            locationContinuation?.resume(throwing: LocationError.locationUnknownSimulator)
            #else
            locationContinuation?.resume(throwing: LocationError.locationUnknown)
            #endif
            locationContinuation = nil
            didRetryLocationUnknown = false
            return
        }

        // Propagate other errors
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
        didRetryLocationUnknown = false
    }
}

// MARK: - Errors
enum LocationError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case locationUnknown
    case locationUnknownSimulator
    case unknown

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "Location services are disabled"
        case .permissionDenied:
            return "Location permission denied"
        case .locationUnknown:
            return "Unable to determine your location. Please try again."
        case .locationUnknownSimulator:
            return "Simulator location not set. Please set a custom location in Xcode: Debug → Location → Custom Location"
        case .unknown:
            return "Unknown location error"
        }
    }
}

