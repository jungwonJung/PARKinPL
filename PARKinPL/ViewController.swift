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
    private var cityList: [String] = []
    private let cityPlaceholderTitle = "City"
    private let arrowImage = UIImage(systemName: "chevron.down")

    override func viewDidLoad() {
        super.viewDidLoad()
        // Force light mode regardless of system setting
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .systemBackground
        styleSearchButton()

        configureCityButtonForPlaceholder()
        loadAvailableCities()

        mapView.delegate = self
        mapView.showsUserLocation = true
    }
    
    private func loadAvailableCities() {
        cityList = zoneService.getAvailableCities()
        print("[VC] Loaded \(cityList.count) cities from data files")
    }

    // MARK: - UI
    private func styleSearchButton() {
        searchButton.setTitle("Search", for: .normal)
        searchButton.backgroundColor = .label
        searchButton.setTitleColor(.systemBackground, for: .normal)
        searchButton.layer.cornerRadius = 14
    }

    // Configures the city button to show placeholder text with dropdown arrow
    private func configureCityButtonForPlaceholder() {
        cityButton.setTitle(cityPlaceholderTitle, for: .normal)
        cityButton.setTitleColor(.label, for: .normal)
        cityButton.setImage(arrowImage, for: .normal)

        // Image placement on iOS 15+
        if #available(iOS 15.0, *) {
            var config = cityButton.configuration ?? .plain()
            config.imagePlacement = .trailing
            config.imagePadding = 6
            cityButton.configuration = config
        } else {
            // Fallback for iOS 14
            cityButton.semanticContentAttribute = .forceRightToLeft
            cityButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        }
    }

    // Updates button after city selection: removes arrow, shows city name
    private func applyCitySelected(_ city: String) {
        cityButton.setTitle(city, for: .normal)
        cityButton.setImage(nil, for: .normal)
        cityButton.setTitleColor(.label, for: .normal)
    }

    // Returns selected city, or nil if placeholder is still showing
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
        print("[Search] Starting search for city: \(city)")
        print("[Search] Location: lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude)")
        
        // Test: Override with Polish location if in simulator
        let testLocation = location
        #if targetEnvironment(simulator)
        // Use a real Polish location for testing
        let polishLocation = CLLocation(latitude: 50.0619, longitude: 19.9366) // Kraków Rynek
        // Uncomment next line to use test location:
        // let testLocation = polishLocation
        #endif
        
        do {
            // Get street address from location
            let address = try await geocodingService.getStreetName(from: testLocation)
            let streetDisplay = address.streetNumber.map { "\(address.streetName) \($0)" } ?? address.streetName
            print("[Geocode] Current location address: \(streetDisplay)")
            
            // Load zones for city
            let zones = try await zoneService.loadZones(for: city)
            print("[Service] Loaded \(zones.count) zones for \(city)")
            
            // Find matching zone
            if let matchingZone = zoneService.findZone(for: address, at: testLocation, in: zones) {
                print("[Match] Found zone: \(matchingZone.name)")
                await MainActor.run {
                    showZoneResult(matchingZone, street: streetDisplay)
                }
            } else {
                await MainActor.run {
                    showAlert(title: "No Zone Found", message: "No parking zone found for \(streetDisplay) in \(city)")
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
            case .locationUnknown, .locationUnknownSimulator:
                showAlert(title: "Location Error", message: locationError.localizedDescription ?? "Unable to get your location.")
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
        var message = "📍 \(street)\n\n"
        
        // Zone
        message += "🅿️ Zone: \(zone.name)\n\n"
        
        // Rates (using unified formatter)
        message += "💰 Rates:\n"
        if let rateDetails = zone.rateDetails {
            let formattedRates = rateDetails.formattedRates()
            if !formattedRates.isEmpty {
                for rate in formattedRates {
                    message += "• \(rate)\n"
                }
            } else if let hourlyRate = zone.hourlyRate {
                message += "• \(hourlyRate) PLN per hour\n"
            }
        } else if let hourlyRate = zone.hourlyRate {
            message += "• \(hourlyRate) PLN per hour\n"
        }
        
        // Operating hours
        message += "\n⏰ Operating:\n"
        if let days = zone.operatingDays {
            message += "• Days: \(days)\n"
        }
        if let hours = zone.operatingHours {
            message += "• Time: \(hours.start) - \(hours.end)"
        }
        
        let alert = UIAlertController(
            title: "Parking Information",
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
