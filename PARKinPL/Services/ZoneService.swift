import Foundation

/// Handles parking zone data and matching
protocol ZoneService {
    func loadZones(for city: String) async throws -> [ParkingZone]
    func findZone(for address: StreetAddress, in zones: [ParkingZone]) -> ParkingZone?
}

final class ZoneServiceImpl: ZoneService {
    private let dataLoader: ZoneDataLoader
    
    init(dataLoader: ZoneDataLoader = ZoneDataLoaderImpl()) {
        self.dataLoader = dataLoader
    }
    
    func loadZones(for city: String) async throws -> [ParkingZone] {
        return try await dataLoader.loadZones(for: city)
    }
    
    func findZone(for address: StreetAddress, in zones: [ParkingZone]) -> ParkingZone? {
        let normalizedStreet = normalizeStreetName(address.streetName)
        
        for zone in zones {
            for streetInfo in zone.streets {
                // Handle both string format (legacy) and StreetInfo format
                if let streetString = streetInfo as? String {
                    if normalizeStreetName(streetString) == normalizedStreet {
                        return zone
                    }
                } else if let streetDetail = streetInfo as? StreetDetail {
                    if normalizeStreetName(streetDetail.name) == normalizedStreet {
                        // Check if street number is in range
                        if isValidStreetNumber(address.streetNumber, in: streetDetail) {
                            return zone
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isValidStreetNumber(_ number: Int?, in detail: StreetDetail) -> Bool {
        guard let num = number else { return true } // If no number, just match by name
        
        // If there's a range, check it
        if let from = detail.from, let to = detail.to {
            return num >= from && num <= to
        }
        
        return true // No range specified, assume all numbers valid
    }
    
    private func normalizeStreetName(_ street: String) -> String {
        return street
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models
struct StreetDetail: Codable {
    let name: String
    let from: Int?
    let to: Int?
    let numbers: String?
    let notes: String?
}

struct ParkingZone {
    let name: String
    let streets: [Any] // Can be String or StreetDetail
    let hourlyRate: Double?
    let dailyRate: Double?
    let description: String?
}

// MARK: - Data Loading
protocol ZoneDataLoader {
    func loadZones(for city: String) async throws -> [ParkingZone]
}

final class ZoneDataLoaderImpl: ZoneDataLoader {
    func loadZones(for city: String) async throws -> [ParkingZone] {
        // Load JSON file for the city
        let fileName = "zones_\(city.lowercased()).json"
        guard let url = Bundle.main.url(forResource: "zones_\(city.lowercased())", withExtension: "json") else {
            print("[Service] No JSON file found for city: \(city)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let cityData = try decoder.decode(CityParkingData.self, from: data)
            return cityData.zones
        } catch {
            print("[Service] Error loading zones for \(city): \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - JSON Decoding Models
struct CityParkingData: Codable {
    let city: String
    let zones: [ParkingZone]
}

extension ParkingZone: Codable {
    // ParkingZone already defined above with matching properties
}
