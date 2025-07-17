# Solar

An iOS app for tracking solar data, UV index, and air quality with interactive widgets.

## Features

- **Solar Data Tracking**: View sunrise, sunset, golden hour, and twilight times
- **UV Index Monitoring**: Track UV levels with color-coded indicators and hourly charts
- **Air Quality Information**: Monitor air quality index with detailed breakdowns
- **Interactive Widgets**: Home screen widgets for quick access to solar and UV data
- **Location Support**: Automatic location detection or manual city search
- **Beautiful UI**: Clean, modern interface with dynamic gradients based on time of day

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.0+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tylerreckart/solar.git
cd solar
```

2. Open the project in Xcode:
```bash
open Solar.xcodeproj
```

3. Update the bundle identifier and app group:
   - Change bundle identifier from `Haptic-Software-LLC.Solar` to your own
   - Update app group from `group.com.haptic.solar` to match your bundle ID
   - Update both main app and widget extension identifiers

4. Configure code signing:
   - Select your development team in project settings
   - Ensure provisioning profiles are set up for both the main app and widget extension

5. Build and run the project

## Configuration

### API Services

The app uses the free [Open-Meteo API](https://open-meteo.com/) for weather and air quality data. No API key required.

### App Group Setup

The app uses App Groups to share data between the main app and widgets. You'll need to:

1. Create an App Group in your Apple Developer account
2. Update the app group identifier in:
   - `Solar.entitlements`
   - `Solar-WidgetsExtension.entitlements`
   - `SharedDataManager.swift` (both main app and widget)

## Architecture

The app follows a clean architecture pattern:

- **Models**: Data structures for solar information, weather data, and app settings
- **Views**: SwiftUI views for different screens
- **Classes**: Core functionality including location management, API services, and data sharing
- **Components**: Reusable UI components
- **Utilities**: Helper functions and extensions

## Dependencies

- **HappyPath**: Custom Swift package for review management
- **WidgetKit**: Apple's framework for creating widgets
- **CoreLocation**: For location services
- **SwiftUI**: UI framework

## Widget Support

The app includes three types of widgets:

1. **Solar Path Widget**: Shows sun position and daily solar events
2. **UV Index Widget**: Displays current UV index with color coding
3. **Air Quality Widget**: Shows air quality index and status

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License

## Acknowledgments

- Weather data provided by [Open-Meteo](https://open-meteo.com/)
- Icons and design are copyright 2025 Haptic Software, LLC
