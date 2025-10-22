import Foundation
import CoreLocation

/// Handles all location-related operations
protocol LocationService {
    func requestLocation() async throws -> CLLocation
    func requestPermission() async -> CLAuthorizationStatus
}

final class LocationServiceImpl: NSObject, LocationService {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            
            guard CLLocationManager.locationServicesEnabled() else {
                continuation.resume(throwing: LocationError.servicesDisabled)
                return
            }
            
            let status = authorizationStatus
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                continuation.resume(throwing: LocationError.permissionDenied)
            @unknown default:
                continuation.resume(throwing: LocationError.unknown)
            }
        }
    }
    
    func requestPermission() async -> CLAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            let status = authorizationStatus
            if status == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
                // Permission result will be handled in delegate
            } else {
                continuation.resume(returning: status)
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle permission changes if needed
    }
}

// MARK: - Errors
enum LocationError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "Location services are disabled"
        case .permissionDenied:
            return "Location permission denied"
        case .unknown:
            return "Unknown location error"
        }
    }
}
