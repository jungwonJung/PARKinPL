# PARKinPL 🅿️

A native iOS app that helps users find parking zones and rates in major Polish cities.

[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 📱 Features

- **Real-time Zone Detection**: Automatically identifies your current parking zone using GPS
- **Accurate Parking Rates**: Displays up-to-date pricing information for each zone
- **Operating Hours**: Shows when parking fees apply
- **6 Major Cities**: Supports Warsaw, Kraków, Wrocław, Katowice, Łódź, and Pszczyna
- **Privacy-First**: All location processing happens locally on your device
- **100% Free**: No ads, no subscriptions, no in-app purchases

## 🏙️ Supported Cities

| City | Zones | Detection Method |
|------|-------|------------------|
| Warsaw | 2 | Coordinate-based |
| Kraków | 3 | Street name matching |
| Wrocław | 3 | Coordinate-based |
| Katowice | 2 | Street name matching |
| Łódź | 3 | Street name matching |
| Pszczyna | 3 | Street name matching |

## 🛠️ Technical Stack

- **Language**: Swift 5.9+
- **Architecture**: MVVM with Service Layer
- **Minimum iOS**: 16.0+
- **Frameworks**:
  - UIKit (UI)
  - CoreLocation (GPS & Geocoding)
  - MapKit (Map Display)
- **Dependencies**: None (100% native Apple frameworks)

## 🏗️ Architecture

### Key Design Patterns

- **Protocol-Oriented**: Services are protocol-based for testability
- **Async/Await**: Modern Swift concurrency for location operations
- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Local-First**: All data stored in app bundle, no backend required

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 16.0+ device or simulator
- Apple Developer account (for device testing)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/jungwonJung/PARKinPL.git
cd PARKinPL
```

2. Open in Xcode:
```bash
open PARKinPL.xcodeproj
```

3. Select your target device/simulator

4. Build and run (`⌘ + R`)

### Configuration

No additional configuration needed! The app works out of the box.

## 📊 Data Structure

Parking zones are defined in JSON files under `PARKinPL/Data/`:

```json
{
  "city": "Warsaw",
  "zones": [
    {
      "name": "Zone I",
      "streets": ["ulica Marszałkowska", ...],
      "rateDetails": {
        "firstHour": 4.5,
        "secondHour": 5.4,
        "thirdHour": 6.4,
        "fourthAndEachSubsequentHour": 4.5
      },
      "operatingDays": "Monday-Friday",
      "operatingHours": {
        "start": "08:00",
        "end": "20:00"
      },
      "bounds": {
        "minLat": 52.17,
        "maxLat": 52.27,
        "minLon": 20.90,
        "maxLon": 21.10
      }
    }
  ]
}
```

### Adding New Cities

1. Create `zones_cityname.json` in `PARKinPL/Data/`
2. Follow the JSON structure above
3. Add to Xcode project (target: PARKinPL)
4. City will automatically appear in the picker

## 🧪 Testing

### Manual Testing

1. Run on simulator with custom location:
   - Debug → Location → Custom Location
   - Enter Polish coordinates (e.g., Warsaw: 52.2297° N, 21.0122° E)

2. Test location permissions:
   - First launch should prompt for location access
   - Deny → Should show settings alert
   - Allow → Should center map on user location

3. Test zone detection:
   - Select city from picker
   - Tap search button
   - Verify zone and rates display correctly

## 🔒 Privacy & Permissions

### Location Usage

- **When In Use**: Required for zone detection
- **Purpose**: "PARKinPL needs your location to identify your parking zone and show you the correct parking rates."
- **Data Storage**: Location is never stored or transmitted
- **Processing**: 100% on-device

### Third-Party Services

None. This app uses only Apple's native frameworks.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

- Follow Swift API Design Guidelines
- Maintain MVVM architecture
- Add new cities via JSON (no code changes needed)
- Write clear commit messages
- Test on real device before submitting PR

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**jungwonJung**
- GitHub: [@jungwonJung](https://github.com/jungwonJung)
- Email: wjdwjd1501@gmail.com

## 🙏 Acknowledgments

- Parking data sourced from official city websites
- Icon design inspired by Polish road signs
- Built with ❤️ for Polish drivers

## 📞 Support

For bug reports or feature requests, please [open an issue](https://github.com/jungwonJung/PARKinPL/issues).

---

**Note**: This app is not affiliated with any Polish city government. Parking rates and zones are subject to change. Always verify current rates with official sources.
