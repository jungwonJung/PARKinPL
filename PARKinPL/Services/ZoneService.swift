import Foundation
import CoreLocation
import _LocationEssentials

/// Handles parking zone data and matching
protocol ZoneService {
    func loadZones(for city: String) async throws -> [ParkingZone]
    func findZone(for address: StreetAddress, at location: CLLocation?, in zones: [ParkingZone]) -> ParkingZone?
    func getAvailableCities() -> [String]
}

final class ZoneServiceImpl: ZoneService {
    private let dataLoader: ZoneDataLoader
    
    init(dataLoader: ZoneDataLoader = ZoneDataLoaderImpl()) {
        self.dataLoader = dataLoader
    }
    
    func loadZones(for city: String) async throws -> [ParkingZone] {
        return try await dataLoader.loadZones(for: city)
    }
    
    func getAvailableCities() -> [String] {
        return dataLoader.getAvailableCities()
    }
    
    func findZone(for address: StreetAddress, at location: CLLocation?, in zones: [ParkingZone]) -> ParkingZone? {
        let normalizedStreet = normalizeStreetName(address.streetName)
        
        for zone in zones {
            // Check coordinate bounds first (Warsaw, Wrocław)
            if let location = location, let bounds = zone.bounds {
                if isLocationWithinBounds(location, bounds: bounds) {
                    print("[Match] Found zone by coordinates: \(zone.name)")
                    return zone
                }
            }
            // Fallback to street name matching (Katowice, Kraków)
            if let streets = zone.streets {
                for streetName in streets {
                    if normalizeStreetName(streetName) == normalizedStreet {
                        print("[Match] Found zone by street name: \(zone.name)")
                        return zone
                    }
                }
            }
        }
        return nil
    }
    
    private func isLocationWithinBounds(_ location: CLLocation, bounds: ZoneBounds) -> Bool {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return lat >= bounds.minLat && lat <= bounds.maxLat &&
               lon >= bounds.minLon && lon <= bounds.maxLon
    }
    
    private func normalizeStreetName(_ street: String) -> String {
        return street
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models
struct ParkingZone: Decodable {
    let name: String
    let streets: [String]?
    let hourlyRate: Double?
    let dailyRate: Double?
    let description: String?
    let rateDetails: RateDetails?
    let operatingDays: String?
    let operatingHours: OperatingHours?
    let bankHolidaysExcluded: Bool?
    let bounds: ZoneBounds?
}

struct ZoneBounds: Decodable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
}

// Flexible rate decoding to handle different city-specific keys
struct RateDetails: Decodable {
    let first30Minutes: Double?
    let firstHour: Double?
    let secondHour: Double?
    let thirdHour: Double?
    let eachAdditionalHour: Double?
    let thirtyOneTo60Minutes: Double?
    let each30Minutes: Double?
    
    private enum CodingKeys: String, CodingKey {
        case first30Minutes
        case firstHour
        case secondHour
        case thirdHour
        case each30Minutes
        
        // Unified target keys
        case eachAdditionalHour
        case thirtyOneTo60Minutes
        
        // City-specific alternate keys
        case fourthAndEachSubsequentHour
        case additionalHour
        case fourthPlusHour
        case _31to60Minutes = "31to60Minutes"
        case firstTo60Minutes
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        func decodeDouble(_ keys: [CodingKeys]) -> Double? {
            for k in keys {
                if let v = try? c.decodeIfPresent(Double.self, forKey: k) {
                    return v
                }
            }
            return nil
        }
        
        first30Minutes = decodeDouble([.first30Minutes])
        firstHour      = decodeDouble([.firstHour])
        secondHour     = decodeDouble([.secondHour])
        thirdHour      = decodeDouble([.thirdHour])
        each30Minutes  = decodeDouble([.each30Minutes])
        
        // Map various keys to eachAdditionalHour
        eachAdditionalHour = decodeDouble([
            .eachAdditionalHour,
            .fourthAndEachSubsequentHour,
            .additionalHour,
            .fourthPlusHour
        ])
        
        // Map various keys to thirtyOneTo60Minutes
        thirtyOneTo60Minutes = decodeDouble([
            .thirtyOneTo60Minutes,
            ._31to60Minutes,
            .firstTo60Minutes
        ])
    }
}

struct OperatingHours: Decodable {
    let start: String
    let end: String
}

// MARK: - Display Helpers
extension RateDetails {
    // Returns formatted rate tiers for display
    func formattedRates() -> [String] {
        var rates: [String] = []
        
        // Flat rate per 30 minutes (Pszczyna Zone C style)
        if let flat30 = each30Minutes {
            rates.append("Each 30 min: \(flat30) PLN")
            return rates
        }
        
        // Time-based progressive rates
        if let first30 = first30Minutes {
            rates.append("0-30 min: \(first30) PLN")
        }
        if let min31_60 = thirtyOneTo60Minutes {
            rates.append("31-60 min: \(min31_60) PLN")
        }
        
        // Hourly progressive rates
        if let first = firstHour {
            rates.append("1st hour: \(first) PLN")
        }
        if let second = secondHour {
            rates.append("2nd hour: \(second) PLN")
        }
        if let third = thirdHour {
            rates.append("3rd hour: \(third) PLN")
        }
        if let additional = eachAdditionalHour {
            // Smart labeling based on previous tiers
            if thirdHour != nil {
                rates.append("4th+ hour: \(additional) PLN each")
            } else if secondHour != nil {
                rates.append("3rd+ hour: \(additional) PLN each")
            } else if firstHour != nil {
                rates.append("2nd+ hour: \(additional) PLN each")
            } else {
                rates.append("Each hour: \(additional) PLN")
            }
        }
        
        return rates
    }
}

// MARK: - Data Loading
protocol ZoneDataLoader {
    func loadZones(for city: String) async throws -> [ParkingZone]
    func getAvailableCities() -> [String]
}

final class ZoneDataLoaderImpl: ZoneDataLoader {
    func loadZones(for city: String) async throws -> [ParkingZone] {
        let fileName = "zones_\(city.lowercased())"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
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
    
    func getAvailableCities() -> [String] {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("[Service] Unable to access bundle resources")
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
            let zoneFiles = files.filter { $0.hasPrefix("zones_") && $0.hasSuffix(".json") }
            
            let cities = zoneFiles.compactMap { fileName -> String? in
                // Extract city name from "zones_cityname.json"
                let cityName = fileName
                    .replacingOccurrences(of: "zones_", with: "")
                    .replacingOccurrences(of: ".json", with: "")
                
                // Capitalize first letter
                return cityName.prefix(1).uppercased() + cityName.dropFirst()
            }
            
            print("[Service] Found \(cities.count) cities: \(cities.joined(separator: ", "))")
            return cities.sorted()
        } catch {
            print("[Service] Error reading directory: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - JSON Decoding Models
struct CityParkingData: Decodable {
    let city: String
    let zones: [ParkingZone]
}
