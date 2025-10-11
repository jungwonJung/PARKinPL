import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var currentLocationButton: UIButton!

    // MARK: - Location
    private let locationManager = CLLocationManager()
    private var isCentering = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        styleSearchButton()

        mapView.delegate = self
        mapView.showsUserLocation = true

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - UI styling
    private func styleSearchButton() {
        searchButton.setTitle("Search", for: .normal)
        searchButton.backgroundColor = .label
        searchButton.setTitleColor(.systemBackground, for: .normal)
        searchButton.layer.cornerRadius = 14
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
        ensureLocationAuthorizedThenCenter()
    }

    // MARK: - Location helpers
    private func ensureLocationAuthorizedThenCenter() {
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

    private func finishCentering() {
        isCentering = false
        currentLocationButton.isEnabled = true
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        ensureLocationAuthorizedThenCenter()
    }

    // iOS 13 호환
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        ensureLocationAuthorizedThenCenter()
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

    // MARK: - Map helpers
    private func centerMap(on coordinate: CLLocationCoordinate2D,
                           meters: CLLocationDistance = 300,
                           animated: Bool = true) {
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: meters,
                                        longitudinalMeters: meters)
        mapView.setRegion(region, animated: animated)
    }

    // MARK: - Alerts
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
