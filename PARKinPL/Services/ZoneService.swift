import Foundation
import CoreLocation
import _LocationEssentials

/// Handles parking zone data and matching
protocol ZoneService {
    func loadZones(for city: String) async throws -> [ParkingZone]
    func findZone(for address: StreetAddress, at location: CLLocation?, in zones: [ParkingZone]) -> ParkingZone?
}

final class ZoneServiceImpl: ZoneService {
    private let dataLoader: ZoneDataLoader
    
    init(dataLoader: ZoneDataLoader = ZoneDataLoaderImpl()) {
        self.dataLoader = dataLoader
    }
    
    func loadZones(for city: String) async throws -> [ParkingZone] {
        return try await dataLoader.loadZones(for: city)
    }
    
    func findZone(for address: StreetAddress, at location: CLLocation?, in zones: [ParkingZone]) -> ParkingZone? {
        let normalizedStreet = normalizeStreetName(address.streetName)
        
        for zone in zones {
            // 1) Bounds 우선
            if let location = location, let bounds = zone.bounds {
                if isLocationWithinBounds(location, bounds: bounds) {
                    print("[Match] Found zone by coordinates: \(zone.name)")
                    return zone
                }
            }
            // 2) 도로명 매칭 (streets 옵셔널 안전 처리)
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
struct ParkingZone: Decodable {               // ⬅️ Codable → Decodable
    let name: String
    let streets: [String]?                    // ⬅️ 옵셔널(도시별 데이터 편차 대비)
    let hourlyRate: Double?
    let dailyRate: Double?
    let description: String?
    let rateDetails: RateDetails?
    let operatingDays: String?
    let operatingHours: OperatingHours?
    let bankHolidaysExcluded: Bool?
    let bounds: ZoneBounds?
}

struct ZoneBounds: Decodable {                // ⬅️ Codable → Decodable
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
}

// 🔑 유연 디코딩: 도시별 키를 통합
struct RateDetails: Decodable {               // ⬅️ Codable → Decodable
    let first30Minutes: Double?
    let firstHour: Double?
    let secondHour: Double?
    let thirdHour: Double?
    /// 4시간째 및 이후 공통 요금(여러 키를 여기에 통합)
    let eachAdditionalHour: Double?
    /// 31–60분 요금(여러 키를 여기에 통합)
    let thirtyOneTo60Minutes: Double?
    
    private enum CodingKeys: String, CodingKey {
        case first30Minutes
        case firstHour
        case secondHour
        case thirdHour
        
        // 통합 타겟
        case eachAdditionalHour
        case thirtyOneTo60Minutes
        
        // 도시별/소스별 대체 키들
        case fourthAndEachSubsequentHour           // Warsaw
        case additionalHour                         // alt
        case fourthPlusHour                         // alt
        case _31to60Minutes = "31to60Minutes"       // Katowice
        case firstTo60Minutes                       // alt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        func decodeDouble(_ keys: [CodingKeys]) -> Double? {
            for k in keys {
                if let v = try? c.decodeIfPresent(Double.self, forKey: k) {  // ⬅️ try? 로 변경
                    return v
                }
            }
            return nil
        }
        
        first30Minutes = decodeDouble([.first30Minutes])
        firstHour      = decodeDouble([.firstHour])
        secondHour     = decodeDouble([.secondHour])
        thirdHour      = decodeDouble([.thirdHour])
        
        // 여러 키 → eachAdditionalHour
        eachAdditionalHour = decodeDouble([
            .eachAdditionalHour,
            .fourthAndEachSubsequentHour,
            .additionalHour,
            .fourthPlusHour
        ])
        
        // 여러 키 → thirtyOneTo60Minutes
        thirtyOneTo60Minutes = decodeDouble([
            .thirtyOneTo60Minutes,
            ._31to60Minutes,
            .firstTo60Minutes
        ])
    }
}

struct OperatingHours: Decodable {            // ⬅️ Codable → Decodable
    let start: String
    let end: String
}

// MARK: - Data Loading
protocol ZoneDataLoader {
    func loadZones(for city: String) async throws -> [ParkingZone]
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
}

// MARK: - JSON Decoding Models
struct CityParkingData: Decodable {           // ⬅️ Codable → Decodable
    let city: String
    let zones: [ParkingZone]
}
