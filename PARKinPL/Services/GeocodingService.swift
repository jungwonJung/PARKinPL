import Foundation
import CoreLocation

/// Handles reverse geocoding to get street names from coordinates
protocol GeocodingService {
    func getStreetName(from location: CLLocation) async throws -> String
}

final class GeocodingServiceImpl: GeocodingService {
    private let geocoder = CLGeocoder()
    
    func getStreetName(from location: CLLocation) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let streetName = placemark.thoroughfare else {
                    continuation.resume(throwing: GeocodingError.noStreetFound)
                    return
                }
                
                continuation.resume(returning: streetName)
            }
        }
    }
}

// MARK: - Errors
enum GeocodingError: LocalizedError {
    case noStreetFound
    
    var errorDescription: String? {
        switch self {
        case .noStreetFound:
            return "Could not determine street name from location"
        }
    }
}
