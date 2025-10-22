import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var currentLocationButton: UIButton!
    @IBOutlet weak var cityButton: UIButton!

    // MARK: - Services
    private let locationService: LocationService = LocationServiceImpl()
    private let geocodingService: GeocodingService = GeocodingServiceImpl()
    private let zoneService: ZoneService = ZoneServiceImpl()
    
    // MARK: - State
    private var isCentering = false
    private var lastKnownLocation: CLLocation?

    // MARK: - City
    private let cityList = ["Warsaw", "Kraków", "Wrocław", "Gdańsk", "Poznań"]
    private let cityPlaceholderTitle = "City"          // 버튼의 초기 텍스트
    private let arrowImage = UIImage(systemName: "chevron.down") // 커스텀 이미지면 교체

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        styleSearchButton()

        // 초기 City 버튼 모양 구성
        configureCityButtonForPlaceholder()

        mapView.delegate = self
        mapView.showsUserLocation = true
    }

    // MARK: - UI
    private func styleSearchButton() {
        searchButton.setTitle("Search", for: .normal)
        searchButton.backgroundColor = .label
        searchButton.setTitleColor(.systemBackground, for: .normal)
        searchButton.layer.cornerRadius = 14
    }

    /// "City + 화살표" 상태로 세팅 (폰트/사이즈/굵기 등 버튼 원래 속성 그대로 유지)
    private func configureCityButtonForPlaceholder() {
        cityButton.setTitle(cityPlaceholderTitle, for: .normal)
        cityButton.setTitleColor(.label, for: .normal)    // 필요 시 .secondaryLabel 로
        cityButton.setImage(arrowImage, for: .normal)     // 화살표 붙이기

        // iOS 15+ : 이미지 오른쪽, 간격 설정
        if #available(iOS 15.0, *) {
            var config = cityButton.configuration ?? .plain()
            config.imagePlacement = .trailing
            config.imagePadding = 6
            cityButton.configuration = config
        } else {
            // iOS14 이하 호환: 이미지 오른쪽으로
            cityButton.semanticContentAttribute = .forceRightToLeft
            cityButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        }
    }

    /// 도시 선택 후: 타이틀만 도시명으로 바꾸고 화살표 이미지는 제거
    private func applyCitySelected(_ city: String) {
        cityButton.setTitle(city, for: .normal)
        cityButton.setImage(nil, for: .normal)            // 화살표 제거
        cityButton.setTitleColor(.label, for: .normal)    // 색상만 필요 시 조정
        // 폰트/사이즈/굵기는 버튼의 titleLabel 설정을 건드리지 않았으므로 그대로 유지됩니다.
    }

    /// 현재 선택된 도시 (초기 placeholder면 nil)
    private func currentSelectedCity() -> String? {
        let title = cityButton.title(for: .normal) ?? ""
        return (title == cityPlaceholderTitle) ? nil : title
    }

    // MARK: - Actions
    @IBAction func searchTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        guard let selectedCity = currentSelectedCity() else {
            showAlert(title: "No City Selected", message: "Please select a city first.")
            return
        }
        
        guard let location = lastKnownLocation else {
            showAlert(title: "No Location", message: "Please tap the location button first.")
            return
        }
        
        Task {
            await performSearch(location: location, city: selectedCity)
        }
    }

    @IBAction func locateTapped(_ sender: UIButton) {
        guard !isCentering else { return }
        isCentering = true
        currentLocationButton.isEnabled = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await requestLocationAndCenter()
        }
    }

    /// City 버튼 탭 -> 모달 피커 표시
    @IBAction func cittyButtonTapped(_ sender: UIButton) {
        let vc = CityPickerViewController()
        vc.cityList = cityList

        if let current = currentSelectedCity(),
           let idx = cityList.firstIndex(of: current) {
            vc.preselectIndex = idx
        } else {
            vc.preselectIndex = 0
        }

        vc.onCitySelected = { [weak self] city in
            self?.applyCitySelected(city)
        }

        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    // MARK: - Location Handling
    private func requestLocationAndCenter() async {
        do {
            let location = try await locationService.requestLocation()
            lastKnownLocation = location
            
            await MainActor.run {
                centerMap(on: location.coordinate, meters: 300)
                finishCentering()
            }
        } catch {
            await MainActor.run {
                handleLocationError(error)
                finishCentering()
            }
        }
    }
    
    private func performSearch(location: CLLocation, city: String) async {
        do {
            // Get street name from location
            let streetName = try await geocodingService.getStreetName(from: location)
            print("[Geocode] Found street: \(streetName)")
            
            // Load zones for city
            let zones = try await zoneService.loadZones(for: city)
            print("[Service] Loaded \(zones.count) zones for \(city)")
            
            // Find matching zone
            if let matchingZone = zoneService.findZone(for: streetName, in: zones) {
                print("[Match] Found zone: \(matchingZone.name)")
                await MainActor.run {
                    showZoneResult(matchingZone, street: streetName)
                }
            } else {
                await MainActor.run {
                    showAlert(title: "No Zone Found", message: "No parking zone found for \(streetName) in \(city)")
                }
            }
        } catch {
            await MainActor.run {
                showAlert(title: "Search Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func handleLocationError(_ error: Error) {
        if let locationError = error as? LocationError {
            switch locationError {
            case .permissionDenied:
                showLocationDeniedAlert()
            case .servicesDisabled:
                showAlert(title: "Location Disabled", message: "Please enable location services in Settings.")
            case .unknown:
                showAlert(title: "Location Error", message: "Unable to get your location.")
            }
        } else {
            showAlert(title: "Location Error", message: error.localizedDescription)
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D,
                           meters: CLLocationDistance = 300,
                           animated: Bool = true) {
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: meters,
                                        longitudinalMeters: meters)
        mapView.setRegion(region, animated: animated)
    }

    private func finishCentering() {
        isCentering = false
        currentLocationButton.isEnabled = true
    }

    private func showLocationDeniedAlert() {
        let alert = UIAlertController(
            title: "Location Access Denied",
            message: "Please enable location access in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    private func showZoneResult(_ zone: ParkingZone, street: String) {
        var message = "Street: \(street)\nZone: \(zone.name)"
        
        if let hourlyRate = zone.hourlyRate {
            message += "\nHourly Rate: \(hourlyRate) PLN"
        }
        if let dailyRate = zone.dailyRate {
            message += "\nDaily Rate: \(dailyRate) PLN"
        }
        if let description = zone.description {
            message += "\n\n\(description)"
        }
        
        let alert = UIAlertController(
            title: "Parking Zone Found",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
