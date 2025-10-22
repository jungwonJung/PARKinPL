import Foundation

/// Handles parking zone data and matching
protocol ZoneService {
    func loadZones(for city: String) async throws -> [ParkingZone]
    func findZone(for street: String, in zones: [ParkingZone]) -> ParkingZone?
}

final class ZoneServiceImpl: ZoneService {
    private let dataLoader: ZoneDataLoader
    
    init(dataLoader: ZoneDataLoader = ZoneDataLoaderImpl()) {
        self.dataLoader = dataLoader
    }
    
    func loadZones(for city: String) async throws -> [ParkingZone] {
        return try await dataLoader.loadZones(for: city)
    }
    
    func findZone(for street: String, in zones: [ParkingZone]) -> ParkingZone? {
        let normalizedStreet = normalizeStreetName(street)
        
        for zone in zones {
            for zoneStreet in zone.streets {
                if normalizeStreetName(zoneStreet) == normalizedStreet {
                    return zone
                }
            }
        }
        
        return nil
    }
    
    private func normalizeStreetName(_ street: String) -> String {
        return street
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models
struct ParkingZone {
    let name: String
    let streets: [String]
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
        // TODO: Replace with real JSON loading
        // For now, return mock data
        return mockZones(for: city)
    }
    
    private func mockZones(for city: String) -> [ParkingZone] {
        switch city.lowercased() {
        case "warsaw":
            return [
                ParkingZone(name: "Zone A", streets: ["Krakowskie Przedmieście", "Nowy Świat"], hourlyRate: 3.0, dailyRate: 20.0, description: "City center"),
                ParkingZone(name: "Zone B", streets: ["Marszałkowska", "Jerozolimskie"], hourlyRate: 2.0, dailyRate: 15.0, description: "Business district")
            ]
        case "kraków":
            return [
                ParkingZone(name: "Stare Miasto", streets: ["Rynek Główny", "Floriańska"], hourlyRate: 4.0, dailyRate: 25.0, description: "Old Town"),
                ParkingZone(name: "Kazimierz", streets: ["Szeroka", "Krakowska"], hourlyRate: 2.5, dailyRate: 18.0, description: "Jewish Quarter")
            ]
        default:
            return []
        }
    }
}
