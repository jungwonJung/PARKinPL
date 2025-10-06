//
//  ViewController.swift
//  PARKinPL
//
//  Created by JungWonJung on 05/10/2025.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var locateButton: UIButton!
    
    private var selectedCity: String? {
        didSet { updateNavTitle() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        updateNavTitle()
        styleSearchButton()
    }

    private func updateNavTitle() {
        navigationItem.title = selectedCity ?? "PARKinPL"
    }

    private func styleSeparator() {
        separatorView.layer.shadowColor = UIColor.black.cgColor
        separatorView.layer.shadowOpacity = 0.12
        separatorView.layer.shadowRadius = 4
        separatorView.layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    private func styleSearchButton() {
        searchButton.setTitle("Search", for: .normal)
        searchButton.backgroundColor = .label
        searchButton.setTitleColor(.systemBackground, for: .normal)
        searchButton.layer.cornerRadius = 14
    }

    // ✅ 스토리보드 segue 로 넘어갈 때 데이터 주입
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "showCityPicker",
//           let picker = segue.destination as? CityPickerViewController {
//            picker.cities = ["Katowice", "Wrocław", "Warszawa", "Kraków", "Gdańsk", "Łódź", "Poznań"]
//            picker.preselectedCity = selectedCity
//            picker.onSelect = { [weak self] city in
//                self?.selectedCity = city
//            }
//        }
//    }

    @IBAction func searchTapped(_ sender: UIButton) {
        print("Search tapped")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
