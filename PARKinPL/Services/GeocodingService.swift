import Foundation
import CoreLocation

/// Handles reverse geocoding to get street names from coordinates
protocol GeocodingService {
    func getStreetName(from location: CLLocation) async throws -> StreetAddress
}

struct StreetAddress {
    let streetName: String
    let streetNumber: Int?
}

final class GeocodingServiceImpl: GeocodingService {
    private let geocoder = CLGeocoder()
    
    func getStreetName(from location: CLLocation) async throws -> StreetAddress {
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
                
                // Parse street number from subThoroughfare (house number)
                let streetNumber = Int(placemark.subThoroughfare ?? "")
                
                let address = StreetAddress(
                    streetName: streetName,
                    streetNumber: streetNumber
                )
                
                continuation.resume(returning: address)
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
