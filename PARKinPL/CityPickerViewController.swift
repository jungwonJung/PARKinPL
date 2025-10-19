import UIKit

final class CityPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    let pickerView = UIPickerView()
    let topBar = UIView()
    let titleLabel = UILabel()
    let doneButton = UIButton(type: .system)

    var cityList: [String] = []
    var preselectIndex: Int = 0
    var onCitySelected: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        pickerView.dataSource = self
        pickerView.delegate = self

        topBar.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        pickerView.translatesAutoresizingMaskIntoConstraints = false

        topBar.backgroundColor = .secondarySystemBackground
        titleLabel.text = "Choose City"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center

        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        view.addSubview(topBar)
        topBar.addSubview(titleLabel)
        topBar.addSubview(doneButton)
        view.addSubview(pickerView)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            doneButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            pickerView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pickerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if preselectIndex < cityList.count {
            pickerView.selectRow(preselectIndex, inComponent: 0, animated: false)
        }
    }

    @objc private func doneTapped() {
        let row = pickerView.selectedRow(inComponent: 0)
        guard cityList.indices.contains(row) else { dismiss(animated: true); return }
        onCitySelected?(cityList[row])
        dismiss(animated: true)
    }

    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { cityList.count }

    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        cityList[row]
    }
}
