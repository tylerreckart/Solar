// Solar/Models/SunViewModel.swift

import Foundation
import Combine
import CoreLocation // For CLGeocoder

@MainActor
class SunViewModel: ObservableObject {
    @Published var solarInfo: SolarInfo
    @Published var currentSkyCondition: SkyCondition = .daylight
    @Published var dataLoadingState: DataLoadingState = .idle
    
    @Published var isFetchingLocationDetails: Bool = false
    @Published var isGeocodingCity: Bool = false

    private let appSettings = AppSettings.shared
    private let locationManager = LocationManager()
    private let solarAPIService = SolarAPIService()
    private var cancellables = Set<AnyCancellable>()
    
    // Counter to manage manual city selection flows
    private var manualCitySelectionInProgressCount = 0

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }()

    init(initialCity: String? = nil, initialLat: Double? = nil, initialLon: Double? = nil) {
        self.solarInfo = SolarInfo.placeholder()
        setupBindings()

        if appSettings.useCurrentLocation {
            print("☀️ SunViewModel Init: 'Use Current Location' is ON. Attempting to get current location.")
            requestSolarDataForCurrentLocation()
        } else {
            print("☀️ SunViewModel Init: 'Use Current Location' is OFF. Attempting to load last selected city.")
            let defaults = UserDefaults.standard
            if let cityName = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityName),
               defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLatitude) != nil,
               defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLongitude) != nil {
                let latitude = defaults.double(forKey: UserDefaultsKeys.lastSelectedCityLatitude)
                let longitude = defaults.double(forKey: UserDefaultsKeys.lastSelectedCityLongitude)
                let timezoneId = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
                print("☀️ SunViewModel Init: Found last selected city: \(cityName). Loading.")
                Task {
                    await updateSolarDataForCity(name: cityName, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneId)
                }
            } else {
                print("☀️ SunViewModel Init: No last city and 'Use Current Location' is OFF. Setting error state / default.")
                 Task {
                     await updateSolarDataForCity(name: "Philadelphia", latitude: 39.9526, longitude: -75.1652)
                     self.dataLoadingState = .error(message: "Showing default. Search for a city or enable 'Use Current Location'.")
                 }
            }
        }
    }
    
    private func setupBindings() {
        locationManager.$currentPlacemark
            .compactMap { $0 } // Only process non-nil placemarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] validPlacemark in
                guard let self = self else { return }

                if self.isFetchingLocationDetails {
                    if let location = validPlacemark.location {
                        let cityName = validPlacemark.locality ?? validPlacemark.name ?? "Current Location"
                        let clTimezoneIdentifier = validPlacemark.timeZone?.identifier
                        
                        print("📍 SunViewModel (Placemark Sink): Valid placemark received for '\(cityName)'. Updating solar data.")
                        Task {
                            await self.updateSolarDataForCity(name: cityName,
                                                              latitude: location.coordinate.latitude,
                                                              longitude: location.coordinate.longitude,
                                                              explicitTimezoneIdentifier: clTimezoneIdentifier)
                            // After updateSolarDataForCity completes, reset the flag
                            if self.isFetchingLocationDetails { // Check again as it might have been reset by an error path
                                self.isFetchingLocationDetails = false
                                print("📍 SunViewModel (Placemark Sink Task): Reset isFetchingLocationDetails to false after processing placemark.")
                            }
                        }
                    } else {
                        print("❌ SunViewModel (Placemark Sink): Valid placemark received but location is nil.")
                        self.dataLoadingState = .error(message: "Placemark found, but location coordinates are missing.")
                        if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    }
                }
            }
            .store(in: &cancellables)
        
        appSettings.$useCurrentLocation
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] useCurrent in
                guard let self = self else { return }
                print("☀️ SunViewModel: 'Use Current Location' setting changed to: \(useCurrent)")
                if useCurrent {
                    print("☀️ SunViewModel: User toggled ON 'Use Current Location'. Requesting current location data.")
                    self.requestSolarDataForCurrentLocation()
                } else { // useCurrent is false
                    if self.manualCitySelectionInProgressCount > 0 {
                        print("☀️ SunViewModel: 'Use Current Location' turned OFF, but manualCitySelectionInProgressCount (\(self.manualCitySelectionInProgressCount)) > 0. Letting initiated city selection proceed.")
                    } else {
                        print("☀️ SunViewModel: 'Use Current Location' turned OFF (e.g. via settings) and no manual selection in progress. Loading last persisted city.")
                        let defaults = UserDefaults.standard
                        if let cityName = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityName),
                           let latitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLatitude) as? Double,
                           let longitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLongitude) as? Double {
                            let timezoneId = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
                            if self.solarInfo.city.lowercased() != cityName.lowercased() ||
                               (self.solarInfo.latitude != latitude || self.solarInfo.longitude != longitude) {
                                print("☀️ SunViewModel: Loading last saved city: \(cityName) as 'Use Current Location' is OFF.")
                                Task {
                                    await self.updateSolarDataForCity(name: cityName, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneId)
                                }
                            } else {
                                print("☀️ SunViewModel: Already displaying last saved city data (\(cityName)). No reload needed.")
                            }
                        } else {
                            print("☀️ SunViewModel: No last saved city and 'Use CurrentLocation' is OFF. Prompting user.")
                            self.solarInfo = SolarInfo.placeholder(city: "Select a City")
                            self.dataLoadingState = .error(message: "Please search for a city.")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        appSettings.$notificationsEnabled.dropFirst().sink { [weak self] _ in self?.updateScheduledNotifications() }.store(in: &cancellables)
        appSettings.$sunriseAlert.dropFirst().sink { [weak self] _ in self?.updateScheduledNotifications() }.store(in: &cancellables)
        appSettings.$sunsetAlert.dropFirst().sink { [weak self] _ in self?.updateScheduledNotifications() }.store(in: &cancellables)
        appSettings.$highUVAlert.dropFirst().sink { [weak self] _ in self?.updateScheduledNotifications() }.store(in: &cancellables)

        locationManager.$authorizationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                print("☀️ SunViewModel: Location auth status changed (observer) to \(self.locationManager.statusString)")

                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    if self.appSettings.useCurrentLocation && !self.isFetchingLocationDetails { // Guard against re-entry
                        print("☀️ SunViewModel (Auth Observer): Auth is authorized, 'Use Current Location' is ON, and not already fetching. Requesting current location.")
                        self.requestSolarDataForCurrentLocation()
                    }
                case .denied:
                    if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    if self.appSettings.useCurrentLocation {
                        print("☀️ SunViewModel (Auth Observer): Auth denied but 'Use Current Location' is ON. Setting error state.")
                        self.solarInfo = SolarInfo.placeholder(city: "Location Denied")
                        self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription + " Enable in Settings or turn off 'Use Current Location'.")
                    }
                case .restricted:
                    if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    if self.appSettings.useCurrentLocation {
                        print("☀️ SunViewModel (Auth Observer): Auth restricted and 'Use Current Location' is ON. Setting error state.")
                        self.solarInfo = SolarInfo.placeholder(city: "Location Restricted")
                        self.dataLoadingState = .error(message: LocationError.authorizationRestricted.localizedDescription)
                    }
                case .notDetermined:
                     if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    if self.appSettings.useCurrentLocation {
                         print("☀️ SunViewModel (Auth Observer): Auth is 'Not Determined' and 'Use Current Location' is ON. Waiting for user prompt response.")
                         self.dataLoadingState = .error(message: "Please respond to the location permission prompt, or manage in Settings.")
                    }
                @unknown default:
                    if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    if self.appSettings.useCurrentLocation {
                        self.dataLoadingState = .error(message: "Unknown location permission status.")
                    }
                }
            }
            .store(in: &cancellables)

        locationManager.$error
            .compactMap { $0 } // Only process non-nil errors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedError in
                guard let self = self else { return }
                if self.isFetchingLocationDetails {
                    print("❌ SunViewModel (Error Sink): LocationManager error received: \(receivedError.localizedDescription)")
                    self.dataLoadingState = .error(message: receivedError.localizedDescription)
                    self.isFetchingLocationDetails = false
                }
            }
            .store(in: &cancellables)
    }

    func formatTime(_ date: Date) -> String {
        if let tzIdentifier = solarInfo.timezoneIdentifier, let tz = TimeZone(identifier: tzIdentifier) {
            timeFormatter.timeZone = tz
        } else {
            timeFormatter.timeZone = TimeZone.current
            if solarInfo.timezoneIdentifier != nil {
                 print("⚠️ SunViewModel: Could not create TimeZone for identifier: \(solarInfo.timezoneIdentifier!). Using current device timezone for display.")
            }
        }
        return timeFormatter.string(from: date)
    }
    
    func dataLoadingState_isLoading() -> Bool {
        if case .loading = dataLoadingState { return true }
        return isFetchingLocationDetails || isGeocodingCity // Also consider these flags
    }

    func requestSolarDataForCurrentLocation() {
        guard !isFetchingLocationDetails else {
            print("☀️ SunViewModel: Already fetching location details for current location.")
            return
        }
        
        print("☀️ SunViewModel: Requesting solar data for current location.")
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.isFetchingLocationDetails = true
            self.dataLoadingState = .loading
            locationManager.requestCurrentLocation()
        case .notDetermined:
            self.isFetchingLocationDetails = true
            self.dataLoadingState = .loading
            locationManager.requestLocationPermission()
        case .denied:
            self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription + " Enable in Settings.")
            self.solarInfo = SolarInfo.placeholder(city: "Location Denied")
            if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
        case .restricted:
            self.dataLoadingState = .error(message: LocationError.authorizationRestricted.localizedDescription)
            self.solarInfo = SolarInfo.placeholder(city: "Location Restricted")
            if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
        @unknown default:
            self.dataLoadingState = .error(message: "Unknown location permission status.")
            if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
        }
    }

    func selectCity(name: String, latitude: Double?, longitude: Double?, timezoneIdentifier: String? = nil) {
        Task { @MainActor in
            self.manualCitySelectionInProgressCount += 1
            print("☀️ SunViewModel: selectCity called for '\(name)'. manualCitySelectionInProgressCount = \(self.manualCitySelectionInProgressCount)")

            if appSettings.useCurrentLocation {
                appSettings.useCurrentLocation = false
                print("☀️ SunViewModel: Manually selected city '\(name)'. Turning OFF 'Use Current Location'.")
            }
            
            await self.updateSolarDataForCity(name: name, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneIdentifier)
            
            self.manualCitySelectionInProgressCount -= 1
            // Ensure count doesn't go below zero
            if self.manualCitySelectionInProgressCount < 0 { self.manualCitySelectionInProgressCount = 0 }
            print("☀️ SunViewModel: selectCity completed for '\(name)'. manualCitySelectionInProgressCount = \(self.manualCitySelectionInProgressCount)")
        }
    }

    func geocodeAndSelectCity(name: String) async {
        guard !isGeocodingCity && manualCitySelectionInProgressCount == 0 else { // Prevent re-entry if already geocoding or another manual selection is active
            print("☀️ SunViewModel: GeocodeAndSelectCity skipped for '\(name)', already geocoding or manual selection in progress.")
            return
        }
        print("☀️ SunViewModel: Geocoding and selecting city: \(name)")
        
        await MainActor.run {
            self.manualCitySelectionInProgressCount += 1
            print("☀️ SunViewModel: geocodeAndSelectCity called for '\(name)'. manualCitySelectionInProgressCount = \(self.manualCitySelectionInProgressCount)")
            if self.appSettings.useCurrentLocation {
                self.appSettings.useCurrentLocation = false
                print("☀️ SunViewModel: Manually searching city '\(name)'. Turning OFF 'Use Current Location'.")
            }
            self.isGeocodingCity = true
            self.dataLoadingState = .loading
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(name) { [weak self] (placemarks, error) in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.isGeocodingCity = false

                @MainActor func decrementCounterAndLog(status: String) {
                    self.manualCitySelectionInProgressCount -= 1
                    if self.manualCitySelectionInProgressCount < 0 { self.manualCitySelectionInProgressCount = 0 }
                    print("☀️ SunViewModel: geocodeAndSelectCity \(status) for '\(name)'. manualCitySelectionInProgressCount = \(self.manualCitySelectionInProgressCount)")
                }

                if let clError = error {
                    print("❌ SunViewModel: Geocoding error for \(name): \(clError.localizedDescription)")
                    self.dataLoadingState = .error(message: "Could not find coordinates for \"\(name)\". \(clError.localizedDescription)")
                    decrementCounterAndLog(status: "failed (geocoding error)")
                    return
                }
                
                guard let placemark = placemarks?.first, let location = placemark.location else {
                    print("⚠️ SunViewModel: No coordinates found for \(name).")
                    self.dataLoadingState = .error(message: "No coordinates found for \"\(name)\".")
                    decrementCounterAndLog(status: "failed (no coords)")
                    return
                }
                
                let bestName = placemark.locality ?? placemark.name ?? name
                let clTimezoneIdentifier = placemark.timeZone?.identifier
                
                await self.updateSolarDataForCity(name: bestName,
                                                  latitude: location.coordinate.latitude,
                                                  longitude: location.coordinate.longitude,
                                                  explicitTimezoneIdentifier: clTimezoneIdentifier)
                
                decrementCounterAndLog(status: "completed")
            }
        }
    }
    
    private func updateSolarDataForCity(name: String, latitude: Double?, longitude: Double?, explicitTimezoneIdentifier: String? = nil) async {
        // If this update is for a current GPS location, ensure isFetchingLocationDetails is true
        // For manual city, isFetchingLocationDetails is not the primary flag, isGeocodingCity might be.
        if name == "Current Location" || (appSettings.useCurrentLocation && self.isFetchingLocationDetails) {
             // This implies it's part of a "current location" flow
        } else {
            // This is for a manually selected city
        }
        dataLoadingState = .loading
        
        guard let lat = latitude, let lon = longitude else {
            dataLoadingState = .error(message: "Latitude/Longitude not available for \(name).")
            // If this was part of a current location fetch, reset the flag
            if appSettings.useCurrentLocation && self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
            return
        }

        print("☀️ SunViewModel: Attempting to fetch solar data for \(name) at Lat: \(lat), Lon: \(lon)")
        do {
            let apiResponse = try await solarAPIService.fetchSolarData(latitude: lat, longitude: lon)
            let locationTimezoneIdentifier = apiResponse.timezone
            
            guard let firstDateStr = apiResponse.daily.time.first,
                  let firstSunriseStr = apiResponse.daily.sunrise.first,
                  let firstSunsetStr = apiResponse.daily.sunset.first,
                  let currentDate = solarAPIService.parseDateOnlyString(firstDateStr),
                  let sunriseDate = solarAPIService.parseDateTimeString(firstSunriseStr, timezoneIdentifier: locationTimezoneIdentifier),
                  let sunsetDate = solarAPIService.parseDateTimeString(firstSunsetStr, timezoneIdentifier: locationTimezoneIdentifier) else {
                dataLoadingState = .error(message: "Could not parse date/time strings for \(name).")
                if appSettings.useCurrentLocation && self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                return
            }
            
            let uvMax = apiResponse.daily.uv_index_max.first ?? nil
            let uvIndexInt = Int(round(uvMax ?? 0.0))
            var uvCategory = "Low"; if uvIndexInt >= 11 { uvCategory = "Extreme" } else if uvIndexInt >= 8 { uvCategory = "Very High" } else if uvIndexInt >= 6 { uvCategory = "High" } else if uvIndexInt >= 3 { uvCategory = "Moderate" }
            var parsedHourlyUV: [SolarInfo.HourlyUV] = []
            let solarNoonDate = Date(timeInterval: (sunsetDate.timeIntervalSince(sunriseDate) / 2), since: sunriseDate)
            var currentHourWeatherCode: Int? = nil; var currentHourCloudCover: Int? = nil

            if let hourly = apiResponse.hourly, let weatherCodes = hourly.weathercode, let cloudCovers = hourly.cloudcover {
                let hourlyTimeStrings = hourly.time; let now = Date(); var locationCalendar = Calendar(identifier: .gregorian)
                if let tz = TimeZone(identifier: locationTimezoneIdentifier) { locationCalendar.timeZone = tz } else { locationCalendar.timeZone = TimeZone.current }
                let currentHourInLocation = locationCalendar.component(.hour, from: now)
                for (index, timeString) in hourlyTimeStrings.enumerated() {
                    if let date = solarAPIService.parseDateTimeString(timeString, timezoneIdentifier: locationTimezoneIdentifier) {
                         if locationCalendar.isDate(date, inSameDayAs: now) && locationCalendar.component(.hour, from: date) == currentHourInLocation {
                            if index < weatherCodes.count { currentHourWeatherCode = weatherCodes[index] }
                            if index < cloudCovers.count { currentHourCloudCover = cloudCovers[index] }
                            break
                         }
                    }
                }
                if let hourlyAPIData = apiResponse.hourly, let hourlyTimes = hourlyAPIData.time as? [String], let hourlyUVIndices = hourlyAPIData.uv_index as? [Double?]? {
                    let now = Date(); let calendar = Calendar.current; var localCalendar = Calendar(identifier: .gregorian)
                    if let tz = TimeZone(identifier: locationTimezoneIdentifier) { localCalendar.timeZone = tz } else { localCalendar.timeZone = TimeZone.current }
                    for i in 0..<hourlyTimes.count {
                        if i < hourlyUVIndices?.count ?? 0, let uvValueOptional = hourlyUVIndices?[i], let date = solarAPIService.parseDateTimeString(hourlyTimes[i], timezoneIdentifier: locationTimezoneIdentifier) {
                            if date >= now || calendar.isDate(date,inSameDayAs: now) { parsedHourlyUV.append(SolarInfo.HourlyUV(time: date, uvIndex: uvValueOptional)) }
                        }
                    }
                    parsedHourlyUV = parsedHourlyUV.filter { $0.time >= now && $0.time <= calendar.date(byAdding: .hour, value: 12, to: now)! }.sorted { $0.time < $1.time }
                }
            }
            
            let dailyApiData = apiResponse.daily
            let civilTwilightBegin = dailyApiData.civil_twilight_begin?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let civilTwilightEnd = dailyApiData.civil_twilight_end?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let nauticalTwilightBegin = dailyApiData.nautical_twilight_begin?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let nauticalTwilightEnd = dailyApiData.nautical_twilight_end?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let astronomicalTwilightBegin = dailyApiData.astronomical_twilight_begin?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let astronomicalTwilightEnd = dailyApiData.astronomical_twilight_end?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let moonrise = dailyApiData.moonrise?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let moonset = dailyApiData.moonset?.first.flatMap{$0}.flatMap{solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier)}
            let moonIllumination = dailyApiData.moon_phase?.first.flatMap{$0}
            let currentSunPosition = SunPositionCalculator.calculateSunPosition(date: Date(), latitude: lat, longitude: lon, timezoneIdentifier: locationTimezoneIdentifier)

            self.solarInfo = SolarInfo(city: name, latitude: lat, longitude: lon, currentDate: currentDate, sunrise: sunriseDate, sunset: sunsetDate, solarNoon: solarNoonDate, timezoneIdentifier: locationTimezoneIdentifier, hourlyUVData: parsedHourlyUV, currentAltitude: currentSunPosition?.altitude ?? 0.0, currentAzimuth: currentSunPosition?.azimuth ?? 0.0, uvIndex: uvIndexInt, uvIndexCategory: uvCategory, civilTwilightBegin: civilTwilightBegin, civilTwilightEnd: civilTwilightEnd, nauticalTwilightBegin: nauticalTwilightBegin, nauticalTwilightEnd: nauticalTwilightEnd, astronomicalTwilightBegin: astronomicalTwilightBegin, astronomicalTwilightEnd: astronomicalTwilightEnd, moonrise: moonrise, moonset: moonset, moonIlluminationFraction: moonIllumination, weatherCode: currentHourWeatherCode, cloudCover: currentHourCloudCover)
            
            var tempSolarInfo = self.solarInfo
            do {
                let aqiResponse = try await solarAPIService.fetchAirQualityData(latitude: lat, longitude: lon)
                if let currentAQI = aqiResponse.current { tempSolarInfo.usAQI = currentAQI.us_aqi; tempSolarInfo.pm2_5 = currentAQI.pm2_5 }
                self.solarInfo = tempSolarInfo; print("💨 SunViewModel: Successfully fetched and updated AQI data.")
            } catch { print("❌ SunViewModel: Failed to fetch AQI data: \(error.localizedDescription)") }
            
            updateScheduledNotifications(); updateSkyCondition(); dataLoadingState = .success
            print("✅ SunViewModel: Successfully updated solar data for \(name) (TZ: \(locationTimezoneIdentifier)). Sunrise: \(formatTime(sunriseDate)), Sunset: \(formatTime(sunsetDate))")
            
            if !appSettings.useCurrentLocation { // Only save to UserDefaults if not using current GPS location
                let defaults = UserDefaults.standard
                defaults.set(self.solarInfo.city, forKey: UserDefaultsKeys.lastSelectedCityName)
                if let savedLat = self.solarInfo.latitude, let savedLon = self.solarInfo.longitude {
                    defaults.set(savedLat, forKey: UserDefaultsKeys.lastSelectedCityLatitude)
                    defaults.set(savedLon, forKey: UserDefaultsKeys.lastSelectedCityLongitude)
                }
                defaults.set(self.solarInfo.timezoneIdentifier, forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
                print("✅ SunViewModel: Saved '\(self.solarInfo.city)' as last selected city (since 'Use Current Location' is OFF).")
            } else {
                 print("✅ SunViewModel: Data updated for current location. Not overwriting last *manually selected* city in UserDefaults.")
            }

        } catch { // Catches errors from solarAPIService.fetchSolarData and parsing
            print("❌ SunViewModel: Error fetching or parsing solar data for \(name): \(error.localizedDescription)")
            dataLoadingState = .error(message: "Failed to get solar data: \(error.localizedDescription)")
        }
        // Ensure isFetchingLocationDetails is reset if this was a current location update
        // This check needs to be careful not to interfere if it's a manual city update.
        // It's reset in the calling contexts (placemark sink, error sink for current location flows).
    }

    private func updateSkyCondition() { /* ... (no changes needed here) ... */ }
    func updateScheduledNotifications() { /* ... (no changes needed here) ... */ }
    private func calculateSunAltitude(latitude: Double, date: Date, timezoneIdentifier: String?) -> Double { /* ... */ return 0.0}
    private func calculateSunAzimuth(latitude: Double, date: Date, timezoneIdentifier: String?) -> Double { /* ... */ return 0.0}
    
    func refreshSolarDataForCurrentCity() {
        guard !isFetchingLocationDetails && !isGeocodingCity && manualCitySelectionInProgressCount == 0 else {
            print("☀️ SunViewModel: Refresh skipped, already fetching/processing location details or geocoding city.")
            return
        }
        Task {
            if appSettings.useCurrentLocation {
                 print("☀️ SunViewModel: Refreshing data for current GPS location ('Use Current Location' is ON).")
                requestSolarDataForCurrentLocation()
            } else {
                print("☀️ SunViewModel: Refreshing data for city: \(solarInfo.city) ('Use Current Location' is OFF).")
                await updateSolarDataForCity(name: solarInfo.city, latitude: solarInfo.latitude, longitude: solarInfo.longitude, explicitTimezoneIdentifier: solarInfo.timezoneIdentifier)
            }
        }
    }
    
    func requestLocationPermission() { locationManager.requestLocationPermission() }
}
