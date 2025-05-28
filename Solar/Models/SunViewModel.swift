// Solar/Models/SunViewModel.swift

import Foundation
import Combine
import CoreLocation // For CLGeocoder
import UserNotifications // For notification logic

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
            .compactMap { $0 }
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
                            if self.isFetchingLocationDetails {
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
                } else {
                    if self.manualCitySelectionInProgressCount > 0 {
                        print("☀️ SunViewModel: 'Use Current Location' turned OFF, but manualCitySelectionInProgressCount (\(self.manualCitySelectionInProgressCount)) > 0. Letting initiated city selection proceed.")
                    } else {
                        print("☀️ SunViewModel: 'Use Current Location' turned OFF and no manual selection in progress. Loading last persisted city.")
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
        
        // Update notifications when any relevant setting changes
        Publishers.MergeMany(
            appSettings.$notificationsEnabled.dropFirst().eraseToAnyPublisher(),
            appSettings.$sunriseAlert.dropFirst().eraseToAnyPublisher(),
            appSettings.$sunsetAlert.dropFirst().eraseToAnyPublisher(),
            appSettings.$highUVAlert.dropFirst().eraseToAnyPublisher()
        )
        .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main) // Debounce to avoid rapid updates
        .sink { [weak self] _ in
            print("🗓️ Notifications: Settings changed, updating scheduled notifications.")
            self?.updateScheduledNotifications()
        }
        .store(in: &cancellables)

        locationManager.$authorizationStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                print("☀️ SunViewModel: Location auth status changed (observer) to \(self.locationManager.statusString)")
                // Potentially trigger notification update if permissions change, handled by SolarApp for appSettings
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    if self.appSettings.useCurrentLocation && !self.isFetchingLocationDetails {
                        print("☀️ SunViewModel (Auth Observer): Auth is authorized, 'Use Current Location' is ON. Requesting current location.")
                        self.requestSolarDataForCurrentLocation()
                    }
                case .denied:
                    if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    if self.appSettings.useCurrentLocation {
                        print("☀️ SunViewModel (Auth Observer): Auth denied. Setting error state.")
                        self.solarInfo = SolarInfo.placeholder(city: "Location Denied")
                        self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription + " Enable in Settings or turn off 'Use Current Location'.")
                    }
                // ... other cases
                default:
                    if self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
                    if self.appSettings.useCurrentLocation {
                         self.dataLoadingState = .error(message: "Location permission status: \(self.locationManager.statusString). Manage in Settings.")
                    }
                }
            }
            .store(in: &cancellables)

        locationManager.$error
            .compactMap { $0 }
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
        return isFetchingLocationDetails || isGeocodingCity
    }

    func requestSolarDataForCurrentLocation() {
        // ... (existing implementation)
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
            self.isFetchingLocationDetails = true // Set loading state while waiting for prompt
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
        // ... (existing implementation)
        Task { @MainActor in
            self.manualCitySelectionInProgressCount += 1
            print("☀️ SunViewModel: selectCity called for '\(name)'. manualCitySelectionInProgressCount = \(self.manualCitySelectionInProgressCount)")

            if appSettings.useCurrentLocation {
                appSettings.useCurrentLocation = false // This will trigger its own sink
                print("☀️ SunViewModel: Manually selected city '\(name)'. Turning OFF 'Use Current Location'.")
            }
            
            await self.updateSolarDataForCity(name: name, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneIdentifier)
            
            self.manualCitySelectionInProgressCount -= 1
            if self.manualCitySelectionInProgressCount < 0 { self.manualCitySelectionInProgressCount = 0 }
            print("☀️ SunViewModel: selectCity completed for '\(name)'. manualCitySelectionInProgressCount = \(self.manualCitySelectionInProgressCount)")
        }
    }

    func geocodeAndSelectCity(name: String) async {
        // ... (existing implementation)
        guard !isGeocodingCity && manualCitySelectionInProgressCount == 0 else {
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
        dataLoadingState = .loading
        // ... (rest of the existing data fetching logic) ...
        guard let lat = latitude, let lon = longitude else {
            dataLoadingState = .error(message: "Latitude/Longitude not available for \(name).")
            if appSettings.useCurrentLocation && self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
            return
        }

        print("☀️ SunViewModel: Attempting to fetch solar data for \(name) at Lat: \(lat), Lon: \(lon)")
        do {
            let apiResponse = try await solarAPIService.fetchSolarData(latitude: lat, longitude: lon)
            // ... (existing parsing logic for solar data)
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
                        // Ensure hourlyUVIndices is not nil and i is a valid index
                        if let uvIndices = hourlyUVIndices, i < uvIndices.count, let uvValueOptional = uvIndices[i], let date = solarAPIService.parseDateTimeString(hourlyTimes[i], timezoneIdentifier: locationTimezoneIdentifier) {
                            // Check if date is today and time is in the future OR if date is in the future (for multi-day forecast, though current is 1 day)
                            if (localCalendar.isDateInToday(date) && date >= now) || date > now {
                                parsedHourlyUV.append(SolarInfo.HourlyUV(time: date, uvIndex: uvValueOptional))
                            }
                        }
                    }
                    // Further filter to relevant future hours for today, e.g., next 12 hours, and sort
                    let endOfDayToday = localCalendar.endOfDay(for: now)
                    parsedHourlyUV = parsedHourlyUV.filter { $0.time >= now && $0.time <= endOfDayToday }.sorted { $0.time < $1.time }

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
            
            updateSkyCondition() // Update sky condition based on new data
            updateScheduledNotifications() // Crucially, update notifications AFTER solarInfo is set
            dataLoadingState = .success
            print("✅ SunViewModel: Successfully updated solar data for \(name) (TZ: \(locationTimezoneIdentifier)). Sunrise: \(formatTime(sunriseDate)), Sunset: \(formatTime(sunsetDate))")
            
            if !appSettings.useCurrentLocation {
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

        } catch {
            print("❌ SunViewModel: Error fetching or parsing solar data for \(name): \(error.localizedDescription)")
            dataLoadingState = .error(message: "Failed to get solar data: \(error.localizedDescription)")
        }
        if appSettings.useCurrentLocation && self.isFetchingLocationDetails { self.isFetchingLocationDetails = false }
    }

    private func updateSkyCondition() {
        let now = Date()
        // Ensure solarInfo has valid, non-placeholder dates before proceeding
        guard solarInfo.sunrise != SolarInfo.placeholder().sunrise,
              solarInfo.sunset != SolarInfo.placeholder().sunset else {
            currentSkyCondition = .daylight // Default or a specific "unknown" state
            return
        }

        // Define thresholds for sunrise/sunset periods (e.g., 30 minutes around the event)
        let sunriseThreshold: TimeInterval = 30 * 60
        let sunsetThreshold: TimeInterval = 30 * 60

        if now < solarInfo.sunrise.addingTimeInterval(-sunriseThreshold) { // Well before sunrise
            currentSkyCondition = .night
        } else if now >= solarInfo.sunrise.addingTimeInterval(-sunriseThreshold) && now <= solarInfo.sunrise.addingTimeInterval(sunriseThreshold) {
            currentSkyCondition = .sunrise
        } else if now > solarInfo.sunrise.addingTimeInterval(sunriseThreshold) && now < solarInfo.sunset.addingTimeInterval(-sunsetThreshold) {
            currentSkyCondition = .daylight
        } else if now >= solarInfo.sunset.addingTimeInterval(-sunsetThreshold) && now <= solarInfo.sunset.addingTimeInterval(sunsetThreshold) {
            currentSkyCondition = .sunset
        } else { // Well after sunset
            currentSkyCondition = .night
        }
        print("🌅 Sky condition updated to: \(currentSkyCondition)")
    }
    
    func updateScheduledNotifications() {
        print("🗓️ Notifications: Attempting to update scheduled notifications.")

        NotificationScheduler.shared.getNotificationAuthorizationStatus { [weak self] status in
            guard let self = self else { return }

            guard status == .authorized || status == .provisional else {
                print("🗓️ Notifications: System permission not granted (\(status)). Cancelling all and skipping scheduling.")
                NotificationScheduler.shared.cancelAllNotifications()
                // Ensure app settings reflect this if SolarApp hasn't already
                if self.appSettings.notificationsEnabled {
                    // self.appSettings.notificationsEnabled = false // Let SolarApp handle this to avoid loops
                    print("🗓️ Notifications: System permission denied, but app setting was true. SolarApp should correct this.")
                }
                return
            }

            // Proceed with scheduling if authorized by system
            NotificationScheduler.shared.cancelAllNotifications() // Clear existing first

            guard self.appSettings.notificationsEnabled else {
                print("🗓️ Notifications: Master notifications toggle is OFF in AppSettings. All notifications cancelled, skipping new scheduling.")
                return
            }
            
            print("🗓️ Notifications: Master toggle is ON. Proceeding with individual alert checks.")

            // Validate solarInfo data (ensure it's not placeholder)
            let placeholder = SolarInfo.placeholder()
            guard self.solarInfo.sunrise != placeholder.sunrise,
                  self.solarInfo.sunset != placeholder.sunset,
                  self.solarInfo.city != placeholder.city || self.solarInfo.city == "Current Location" // Allow "Current Location" if data is fresh
            else {
                print("🗓️ Notifications: SolarInfo contains placeholder data or invalid city. Skipping scheduling. City: \(self.solarInfo.city)")
                return
            }
            
            let cityName = self.solarInfo.city

            // Sunrise Alert
            if self.appSettings.sunriseAlert {
                print("🗓️ Notifications: Sunrise alert is ON.")
                let sunriseTime = self.solarInfo.sunrise
                // Schedule 15 minutes before sunrise
                let sunriseAlertTime = sunriseTime.addingTimeInterval(-15 * 60)
                if sunriseAlertTime > Date() {
                    NotificationScheduler.shared.scheduleNotification(
                        identifier: "sunriseAlert",
                        title: "Sunrise Soon!",
                        body: "Rise and shine! Sunrise in \(cityName) is at \(self.formatTime(sunriseTime)).",
                        date: sunriseAlertTime
                    )
                } else {
                    print("🗓️ Notifications: Sunrise alert time (\(sunriseAlertTime)) for \(cityName) is in the past. Skipping.")
                }
            } else {
                print("🗓️ Notifications: Sunrise alert is OFF.")
            }

            // Sunset Alert
            if self.appSettings.sunsetAlert {
                print("🗓️ Notifications: Sunset alert is ON.")
                let sunsetTime = self.solarInfo.sunset
                // Schedule 30 minutes before sunset
                let sunsetAlertTime = sunsetTime.addingTimeInterval(-30 * 60)
                if sunsetAlertTime > Date() {
                    NotificationScheduler.shared.scheduleNotification(
                        identifier: "sunsetAlert",
                        title: "Sunset Approaching",
                        body: "Heads up! Sunset in \(cityName) is at \(self.formatTime(sunsetTime)).",
                        date: sunsetAlertTime
                    )
                } else {
                    print("🗓️ Notifications: Sunset alert time (\(sunsetAlertTime)) for \(cityName) is in the past. Skipping.")
                }
            } else {
                print("🗓️ Notifications: Sunset alert is OFF.")
            }

            // High UV Alert
            if self.appSettings.highUVAlert {
                print("🗓️ Notifications: High UV alert is ON.")
                let highUVThreshold = 6 // Define your threshold
                var scheduledFirstHighUV = false // To potentially only schedule one UV alert

                for uvItem in self.solarInfo.hourlyUVData {
                    let uvIndexValue = Int(round(uvItem.uvIndex))
                    let alertTime = uvItem.time // Schedule for the start of the hour

                    if uvIndexValue >= highUVThreshold && alertTime > Date() {
                        // Optional: Only schedule the *first* upcoming high UV alert to avoid spam
                        // if scheduledFirstHighUV { continue }
                        
                        NotificationScheduler.shared.scheduleUVNotification(
                            identifier: "highUVAlert_\(uvItem.id)", // Unique ID per hour slot
                            title: "High UV Warning!",
                            body: "UV Index in \(cityName) will be \(uvIndexValue) (\(uvItem.uvCategory)) around \(self.formatTime(alertTime)). Protect your skin!",
                            date: alertTime,
                            uvIndex: uvIndexValue,
                            threshold: highUVThreshold
                        )
                        scheduledFirstHighUV = true // If only scheduling one
                        // if you want multiple, remove scheduledFirstHighUV and the continue
                    } else if alertTime <= Date() {
                         // print("🗓️ Notifications: UV alert for \(self.formatTime(alertTime)) in \(cityName) is in the past or UV not high enough. UV: \(uvIndexValue). Skipping.")
                    }
                }
                if !scheduledFirstHighUV && !self.solarInfo.hourlyUVData.filter({ Int(round($0.uvIndex)) >= highUVThreshold && $0.time > Date() }).isEmpty {
                    // This case should ideally not be hit if logic above is correct
                    print("🗓️ Notifications: No future high UV alerts were scheduled, though data might exist.")
                } else if self.solarInfo.hourlyUVData.filter({ Int(round($0.uvIndex)) >= highUVThreshold && $0.time > Date() }).isEmpty {
                    print("🗓️ Notifications: No upcoming hours with UV Index >= \(highUVThreshold) found for \(cityName).")
                }


            } else {
                print("🗓️ Notifications: High UV alert is OFF.")
            }
            print("🗓️ Notifications: Finished updating scheduled notifications for \(cityName).")
        }
    }
    
    func refreshSolarDataForCurrentCity() {
        // ... (existing implementation)
        guard !isFetchingLocationDetails && !isGeocodingCity && manualCitySelectionInProgressCount == 0 else {
            print("☀️ SunViewModel: Refresh skipped, already fetching/processing location details or geocoding city.")
            return
        }
        Task {
            if appSettings.useCurrentLocation {
                 print("☀️ SunViewModel: Refreshing data for current GPS location ('Use Current Location' is ON).")
                requestSolarDataForCurrentLocation() // This will eventually call updateSolarDataForCity
            } else {
                print("☀️ SunViewModel: Refreshing data for city: \(solarInfo.city) ('Use Current Location' is OFF).")
                await updateSolarDataForCity(name: solarInfo.city, latitude: solarInfo.latitude, longitude: solarInfo.longitude, explicitTimezoneIdentifier: solarInfo.timezoneIdentifier)
            }
        }
    }
    
    func requestLocationPermission() { locationManager.requestLocationPermission() }
}

// Helper extension for Calendar
extension Calendar {
    func endOfDay(for date: Date) -> Date {
        let startOfDay = self.startOfDay(for: date)
        return self.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
    }
}
