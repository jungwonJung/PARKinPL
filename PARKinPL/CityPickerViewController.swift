//
//  CityPickerViewController.swift
//  PARKinPL
//
//  Created by JungWonJung on 05/10/2025.
//

import UIKit

final class CityPickerViewController: UITableViewController, UISearchResultsUpdating {
    // Main에서 주입받을 데이터/콜백
    var cities: [String] = []
    var preselectedCity: String?
    var onSelect: ((String) -> Void)?

    private var filtered: [String] = []
    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select City"
        view.backgroundColor = .systemBackground

        // 검색창
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search city"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        // 테이블
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        filtered = cities
    }

    // 검색 결과 갱신
    func updateSearchResults(for searchController: UISearchController) {
        let q = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            filtered = cities
        } else {
            filtered = cities.filter {
                $0.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        tableView.reloadData()
    }

    // 테이블 데이터
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let city = filtered[indexPath.row]
        cell.textLabel?.text = city
        cell.accessoryType = (city == preselectedCity) ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let city = filtered[indexPath.row]
        onSelect?(city)
        navigationController?.popViewController(animated: true)
    }
}
