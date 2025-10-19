import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var currentLocationButton: UIButton!
    @IBOutlet weak var cityButton: UIButton!

    // MARK: - Location
    private let locationManager = CLLocationManager()
    private var isCentering = false

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

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
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
    }

    @IBAction func locateTapped(_ sender: UIButton) {
        guard !isCentering else { return }
        isCentering = true
        currentLocationButton.isEnabled = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard CLLocationManager.locationServicesEnabled() else {
            showLocationDeniedAlert()
            finishCentering()
            return
        }

        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            showLocationDeniedAlert()
            finishCentering()
        @unknown default:
            finishCentering()
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

    // MARK: - CLLocationManagerDelegate (그대로)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .denied || status == .restricted {
            showLocationDeniedAlert()
            finishCentering()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else if status == .denied || status == .restricted {
            showLocationDeniedAlert()
            finishCentering()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            if let fallback = mapView.userLocation.location?.coordinate {
                centerMap(on: fallback, meters: 300)
            }
            finishCentering()
            return
        }
        centerMap(on: loc.coordinate, meters: 300)
        finishCentering()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("Location error:", error.localizedDescription)
        #endif
        finishCentering()
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
}
