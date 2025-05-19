//
//  SunViewModel.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

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

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        // Timezone will be set dynamically based on solarInfo.timezoneIdentifier
        return formatter
    }()

    init(initialCity: String? = nil, initialLat: Double? = nil, initialLon: Double? = nil) {
        self.solarInfo = SolarInfo.placeholder()
        setupBindings()

        // --- BEGIN MODIFICATION: Load last selected city ---
        let defaults = UserDefaults.standard
        if let cityName = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityName),
           defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLatitude) != nil, // Check if lat/lon exist
           defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLongitude) != nil {
            let latitude = defaults.double(forKey: UserDefaultsKeys.lastSelectedCityLatitude)
            let longitude = defaults.double(forKey: UserDefaultsKeys.lastSelectedCityLongitude)
            let timezoneId = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)

            print("☀️ SunViewModel: Found last selected city: \(cityName). Attempting to load.")
            Task {
                await updateSolarDataForCity(name: cityName, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneId)
            }
        } else {
            if let city = initialCity, let lat = initialLat, let lon = initialLon {
                Task {
                    await updateSolarDataForCity(name: city, latitude: lat, longitude: lon)
                }
            } else {
                if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                    requestSolarDataForCurrentLocation()
                } else if locationManager.authorizationStatus == .notDetermined {
                    self.dataLoadingState = .error(message: "Location permission not determined. Tap location icon to grant.")
                } else {
                     self.dataLoadingState = .error(message: locationManager.error?.localizedDescription ?? "Enable location services or select a city.")
                     Task { // Fallback to a default city
                         await updateSolarDataForCity(name: "Philadelphia", latitude: 39.9526, longitude: -75.1652)
                     }
                }
            }
        }
    }
    
    private func setupBindings() {
        // Bind to locationManager.currentPlacemark to get timezone from CLPlacemark
        locationManager.$currentPlacemark
            .receive(on: DispatchQueue.main)
            .sink { [weak self] placemark in
                guard let self = self else { return }

                // This is the critical gate: SunViewModel is waiting for a placemark.
                if self.isFetchingLocationDetails {
                    if let validPlacemark = placemark, let location = validPlacemark.location {
                        let cityName = validPlacemark.locality ?? validPlacemark.name ?? "Current Location"
                        let clTimezoneIdentifier = validPlacemark.timeZone?.identifier
                        
                        print("📍 SunViewModel: Placemark received for '\(cityName)'. Updating solar data.")
                        Task {
                            // updateSolarDataForCity will handle setting dataLoadingState to .success or .error
                            await self.updateSolarDataForCity(name: cityName,
                                                              latitude: location.coordinate.latitude,
                                                              longitude: location.coordinate.longitude,
                                                              explicitTimezoneIdentifier: clTimezoneIdentifier)
                        }
                    } else if let locError = self.locationManager.error {
                        // If LocationManager itself had an error during the fetch period
                        print("❌ SunViewModel: Location manager error during active fetch: \(locError.localizedDescription)")
                        self.dataLoadingState = .error(message: locError.localizedDescription)
                    } else {
                        // Placemark is nil, but no specific error from locationManager.error property.
                        // This implies reverse geocoding might have failed to find a placemark.
                        print("⚠️ SunViewModel: Valid placemark not found during active fetch.")
                        self.dataLoadingState = .error(message: LocationError.reverseGeocodingFailed(nil).localizedDescription)
                    }
                    // Crucially, reset the flag AFTER attempting to process or acknowledge failure.
                    self.isFetchingLocationDetails = false
                }
            }
            .store(in: &cancellables)
        
        appSettings.$notificationsEnabled
            .dropFirst()
            .sink { [weak self] _ in self?.updateScheduledNotifications() }
            .store(in: &cancellables)
        appSettings.$sunriseAlert
            .dropFirst()
            .sink { [weak self] _ in self?.updateScheduledNotifications() }
            .store(in: &cancellables)
        appSettings.$sunsetAlert
            .dropFirst()
            .sink { [weak self] _ in self?.updateScheduledNotifications() }
            .store(in: &cancellables)
        appSettings.$highUVAlert
            .dropFirst()
            .sink { [weak self] _ in self?.updateScheduledNotifications() }
            .store(in: &cancellables)

        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                print("☀️ SunViewModel: Location auth status changed to \(self.locationManager.statusString)")
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    // If solarInfo is still placeholder, try to get current location.
                    // This might be called on app start or if permissions change later.
                    if self.solarInfo.city == SolarInfo.placeholder().city && !self.dataLoadingState_isLoading() && !self.isFetchingLocationDetails {
                        print("☀️ SunViewModel: Auth OK and city is placeholder, requesting current location.")
                        self.requestSolarDataForCurrentLocation()
                    }
                case .denied:
                    self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription)
                    self.isFetchingLocationDetails = false // Stop any pending fetch
                case .restricted:
                    self.dataLoadingState = .error(message: LocationError.authorizationRestricted.localizedDescription)
                    self.isFetchingLocationDetails = false // Stop any pending fetch
                case .notDetermined:
                    if self.solarInfo.city == SolarInfo.placeholder().city {
                        self.dataLoadingState = .error(message: "Tap the location icon above to grant location access or search for a city.")
                    }
                    self.isFetchingLocationDetails = false // Stop any pending fetch if one was somehow active
                default:
                    self.dataLoadingState = .error(message: "Unknown location permission status.")
                    self.isFetchingLocationDetails = false // Stop any pending fetch
                }
            }
            .store(in: &cancellables)

        locationManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self = self, let receivedError = error else { return }
                // Only update SunViewModel's state if it was actively trying to fetch location details.
                if self.isFetchingLocationDetails {
                    print("❌ SunViewModel: LocationManager error received during active fetch: \(receivedError.localizedDescription)")
                    self.dataLoadingState = .error(message: receivedError.localizedDescription)
                    self.isFetchingLocationDetails = false // Reset the flag on error too
                }
            }
            .store(in: &cancellables)
    }

    func formatTime(_ date: Date) -> String {
        // Set the timezone on the formatter to the one from the current solarInfo
        // This ensures the displayed time is correct for the selected location's timezone
        if let tzIdentifier = solarInfo.timezoneIdentifier, let tz = TimeZone(identifier: tzIdentifier) {
            timeFormatter.timeZone = tz
        } else {
            // Fallback to current device timezone if no specific one is available (should be rare)
            timeFormatter.timeZone = TimeZone.current
            if solarInfo.timezoneIdentifier != nil { // Log if identifier was present but TimeZone creation failed
                 print("⚠️ SunViewModel: Could not create TimeZone for identifier: \(solarInfo.timezoneIdentifier!). Using current device timezone for display.")
            }
        }
        return timeFormatter.string(from: date)
    }
    
    func dataLoadingState_isLoading() -> Bool {
        if case .loading = dataLoadingState { return true }
        return false
    }

    func requestSolarDataForCurrentLocation() {
        guard !isFetchingLocationDetails else {
            print("☀️ SunViewModel: Already fetching location details.")
            return
        }
        
        print("☀️ SunViewModel: Requesting solar data for current location.")
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.isFetchingLocationDetails = true // ViewModel is now officially waiting
            self.dataLoadingState = .loading     // Set loading state for UI
            locationManager.requestCurrentLocation()
        case .notDetermined:
            // We don't set isFetchingLocationDetails to true here because LocationManager
            // will first ask for permission. The auth status change will be handled.
            locationManager.requestLocationPermission()
            // Update UI to guide user
            self.dataLoadingState = .error(message: "Please grant location permission when prompted.")
        case .denied:
            self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription + " Please enable it in Settings.")
        case .restricted:
            self.dataLoadingState = .error(message: LocationError.authorizationRestricted.localizedDescription)
        @unknown default:
            self.dataLoadingState = .error(message: "Unknown location permission status.")
        }
    }

    func selectCity(name: String, latitude: Double?, longitude: Double?, timezoneIdentifier: String? = nil) {
         Task {
            await self.updateSolarDataForCity(name: name, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneIdentifier)
        }
    }

    func geocodeAndSelectCity(name: String) {
        // ... (logic for geocoding)
        guard !isGeocodingCity else { return }
        print("☀️ SunViewModel: Geocoding and selecting city: \(name)")
        
        isGeocodingCity = true
        dataLoadingState = .loading
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(name) { [weak self] (placemarks, error) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isGeocodingCity = false

                if let clError = error {
                    print("❌ SunViewModel: Geocoding error for \(name): \(clError.localizedDescription)")
                    self.dataLoadingState = .error(message: "Could not find coordinates for \"\(name)\". \(clError.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first, let location = placemark.location else {
                    print("⚠️ SunViewModel: No coordinates found for \(name).")
                    self.dataLoadingState = .error(message: "No coordinates found for \"\(name)\".")
                    return
                }
                
                let bestName = placemark.locality ?? placemark.name ?? name
                let clTimezoneIdentifier = placemark.timeZone?.identifier // Get timezone from geocoding result
                
                await self.updateSolarDataForCity(name: bestName,
                                                  latitude: location.coordinate.latitude,
                                                  longitude: location.coordinate.longitude,
                                                  explicitTimezoneIdentifier: clTimezoneIdentifier)
            }
        }
    }
    
    // Added explicitTimezoneIdentifier for cases where it's known before API call (e.g., from CLPlacemark)
    private func updateSolarDataForCity(name: String, latitude: Double?, longitude: Double?, explicitTimezoneIdentifier: String? = nil) async {
        dataLoadingState = .loading
        
        guard let lat = latitude, let lon = longitude else {
            dataLoadingState = .error(message: "Latitude/Longitude not available for \(name).")
            return
        }

        print("☀️ SunViewModel: Attempting to fetch solar data for \(name) at Lat: \(lat), Lon: \(lon)")
        do {
            let apiResponse = try await solarAPIService.fetchSolarData(latitude: lat, longitude: lon)
            
            // Use the timezone from the API response as the primary source
            let locationTimezoneIdentifier = apiResponse.timezone
            
            guard let firstDateStr = apiResponse.daily.time.first,
                  let firstSunriseStr = apiResponse.daily.sunrise.first,
                  let firstSunsetStr = apiResponse.daily.sunset.first else {
                dataLoadingState = .error(message: "API response missing essential daily data for \(name).")
                return
            }

            // IMPORTANT: Parse date/time strings using the location's specific timezone identifier from the API
            guard let currentDate = solarAPIService.parseDateOnlyString(firstDateStr),
                  let sunriseDate = solarAPIService.parseDateTimeString(firstSunriseStr, timezoneIdentifier: locationTimezoneIdentifier),
                  let sunsetDate = solarAPIService.parseDateTimeString(firstSunsetStr, timezoneIdentifier: locationTimezoneIdentifier) else {
                dataLoadingState = .error(message: "Could not parse date/time strings for \(name) using timezone \(locationTimezoneIdentifier). Check console for details.")
                return
            }
            
            let uvMax = apiResponse.daily.uv_index_max.first ?? nil
            let uvIndexInt = Int(round(uvMax ?? 0.0))
            var uvCategory = "Low"
            if uvIndexInt >= 11 { uvCategory = "Extreme" }
            else if uvIndexInt >= 8 { uvCategory = "Very High" }
            else if uvIndexInt >= 6 { uvCategory = "High" }
            else if uvIndexInt >= 3 { uvCategory = "Moderate" }
            var parsedHourlyUV: [SolarInfo.HourlyUV] = []

            let solarNoonDate = Date(timeInterval: (sunsetDate.timeIntervalSince(sunriseDate) / 2), since: sunriseDate)
            
            var currentHourWeatherCode: Int? = nil
            var currentHourCloudCover: Int? = nil
            if let hourly = apiResponse.hourly,
               let weatherCodes = hourly.weathercode,
               let cloudCovers = hourly.cloudcover {
                
                let hourlyTimeStrings = hourly.time
                let now = Date() // Current instant
                let calendar = Calendar.current // Use a calendar configured for the location's timezone for "current hour"
                var locationCalendar = Calendar(identifier: .gregorian)
                if let tz = TimeZone(identifier: locationTimezoneIdentifier) {
                    locationCalendar.timeZone = tz
                } else {
                    locationCalendar.timeZone = TimeZone.current // Fallback
                }
                
                let currentHourInLocation = locationCalendar.component(.hour, from: now)

                for (index, timeString) in hourlyTimeStrings.enumerated() {
                    // Parse hourly timestamps using the location's timezone
                    if let date = solarAPIService.parseDateTimeString(timeString, timezoneIdentifier: locationTimezoneIdentifier) {
                         let hourOfDataInLocation = locationCalendar.component(.hour, from: date)
                         // Check if the data is for the current day and hour in the location's timezone
                         if locationCalendar.isDate(date, inSameDayAs: now) && hourOfDataInLocation == currentHourInLocation {
                            if index < weatherCodes.count { currentHourWeatherCode = weatherCodes[index] }
                            if index < cloudCovers.count { currentHourCloudCover = cloudCovers[index] }
                            break
                         }
                    }
                }
                
                if let hourlyAPIData = apiResponse.hourly,
                   let hourlyTimes = hourlyAPIData.time as? [String], // Explicit type
                   let hourlyUVIndices = hourlyAPIData.uv_index as? [Double?]? { // Explicit type

                    let now = Date()
                    let calendar = Calendar.current
                    var localCalendar = Calendar(identifier: .gregorian) // Calendar for location's timezone
                    if let tz = TimeZone(identifier: locationTimezoneIdentifier) {
                        localCalendar.timeZone = tz
                    } else {
                        localCalendar.timeZone = TimeZone.current // Fallback
                    }

                    for i in 0..<hourlyTimes.count {
                        if i < hourlyUVIndices?.count ?? 0,
                           let uvValueOptional = hourlyUVIndices?[i],
                           let date = solarAPIService.parseDateTimeString(hourlyTimes[i], timezoneIdentifier: locationTimezoneIdentifier) {

                            if date >= now || calendar.isDate(date,inSameDayAs: now) {
                                parsedHourlyUV.append(SolarInfo.HourlyUV(time: date, uvIndex: uvValueOptional))
                            }
                        }
                    }

                     parsedHourlyUV = parsedHourlyUV.filter { $0.time >= now && $0.time <= calendar.date(byAdding: .hour, value: 12, to: now)! }
                                                    .sorted { $0.time < $1.time }
                }
            }
            
            let dailyApiData = apiResponse.daily
                                    
            let civilTwilightBegin = dailyApiData.civil_twilight_begin?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let civilTwilightEnd = dailyApiData.civil_twilight_end?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let nauticalTwilightBegin = dailyApiData.nautical_twilight_begin?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let nauticalTwilightEnd = dailyApiData.nautical_twilight_end?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let astronomicalTwilightBegin = dailyApiData.astronomical_twilight_begin?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let astronomicalTwilightEnd = dailyApiData.astronomical_twilight_end?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let moonrise = dailyApiData.moonrise?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let moonset = dailyApiData.moonset?.first.flatMap { $0 }.flatMap { solarAPIService.parseDateTimeString($0, timezoneIdentifier: locationTimezoneIdentifier) }
            let moonIllumination = dailyApiData.moon_phase?.first.flatMap { $0 }
            
            let currentSunPosition = SunPositionCalculator.calculateSunPosition(
                date: Date(),
                latitude: lat,
                longitude: lon,
                timezoneIdentifier: locationTimezoneIdentifier
            )

            self.solarInfo = SolarInfo(
                city: name,
                latitude: lat,
                longitude: lon,
                currentDate: currentDate,
                sunrise: sunriseDate,
                sunset: sunsetDate,
                solarNoon: solarNoonDate,
                timezoneIdentifier: locationTimezoneIdentifier,
                hourlyUVData: parsedHourlyUV,
                currentAltitude:  currentSunPosition?.altitude ?? 0.0,
                currentAzimuth: currentSunPosition?.azimuth ?? 0.0,
                uvIndex: uvIndexInt,
                uvIndexCategory: uvCategory,
                civilTwilightBegin: civilTwilightBegin,
                civilTwilightEnd: civilTwilightEnd,
                nauticalTwilightBegin: nauticalTwilightBegin,
                nauticalTwilightEnd: nauticalTwilightEnd,
                astronomicalTwilightBegin: astronomicalTwilightBegin,
                astronomicalTwilightEnd: astronomicalTwilightEnd,
                moonrise: moonrise,
                moonset: moonset,
                moonIlluminationFraction: moonIllumination,
                weatherCode: currentHourWeatherCode,
                cloudCover: currentHourCloudCover
            )
            
            var tempSolarInfo = self.solarInfo
            do {
                let aqiResponse = try await solarAPIService.fetchAirQualityData(latitude: lat, longitude: lon)
                if let currentAQI = aqiResponse.current {
                    tempSolarInfo.usAQI = currentAQI.us_aqi
                    tempSolarInfo.pm2_5 = currentAQI.pm2_5
                }
                self.solarInfo = tempSolarInfo
                print("💨 SunViewModel: Successfully fetched and updated AQI data.")
            } catch {
                print("❌ SunViewModel: Failed to fetch AQI data: \(error.localizedDescription)")
            }
            updateScheduledNotifications()
            updateSkyCondition()
            dataLoadingState = .success
            print("✅ SunViewModel: Successfully updated solar data for \(name) (TZ: \(locationTimezoneIdentifier)). Sunrise: \(formatTime(sunriseDate)), Sunset: \(formatTime(sunsetDate))")
            
            let defaults = UserDefaults.standard
            defaults.set(self.solarInfo.city, forKey: UserDefaultsKeys.lastSelectedCityName)
            if let lat = self.solarInfo.latitude, let lon = self.solarInfo.longitude {
                defaults.set(lat, forKey: UserDefaultsKeys.lastSelectedCityLatitude)
                defaults.set(lon, forKey: UserDefaultsKeys.lastSelectedCityLongitude)
            }
            defaults.set(self.solarInfo.timezoneIdentifier, forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
            print("✅ SunViewModel: Saved '\(self.solarInfo.city)' as last selected city.")

            updateSkyCondition()
            dataLoadingState = .success
            
            updateSkyCondition() // Uses absolute Date objects, so it's fine
            dataLoadingState = .success
            print("✅ SunViewModel: Successfully updated solar data for \(name) (TZ: \(locationTimezoneIdentifier)). Sunrise: \(formatTime(sunriseDate)), Sunset: \(formatTime(sunsetDate))")

        } catch let apiError as APIError {
            print("❌ SunViewModel: API Error fetching solar data for \(name): \(apiError.localizedDescription)")
            dataLoadingState = .error(message: "Failed to fetch solar data: \(apiError.localizedDescription)")
        } catch {
            print("❌ SunViewModel: Unknown error fetching solar data for \(name): \(error.localizedDescription)")
            dataLoadingState = .error(message: "An unexpected error occurred: \(error.localizedDescription)")
        }
    }

    private func updateSkyCondition() {
        // This logic is based on absolute Date objects (sunrise, sunset, Date())
        // So it's inherently correct regardless of timezones, as long as
        // sunrise/sunset Date objects were correctly parsed.
        let now = Date()
        let sunrise = solarInfo.sunrise
        let sunset = solarInfo.sunset
        let twilightOffset: TimeInterval = 30 * 60

        // Ensure sunrise and sunset are valid before proceeding
        guard sunrise < sunset else {
            // Handle invalid sunrise/sunset (e.g. polar regions or error in data)
            // Determine if it's generally day or night based on a rough estimate or default to one
            // For simplicity, if sunrise/sunset are invalid, let's check against noon
            let calendar = Calendar.current
            var noonComponents = calendar.dateComponents([.year, .month, .day], from: now)
            noonComponents.hour = 12
            let approximateNoon = calendar.date(from: noonComponents) ?? now
            if now < approximateNoon.addingTimeInterval(-6 * 3600) || now > approximateNoon.addingTimeInterval(6 * 3600) {
                 currentSkyCondition = .night
            } else {
                 currentSkyCondition = .daylight
            }
            print("⚠️ SunViewModel: Invalid sunrise/sunset times. Sky condition set based on approximate noon.")
            return
        }


        if now < sunrise.addingTimeInterval(-twilightOffset) || now > sunset.addingTimeInterval(twilightOffset) {
            currentSkyCondition = .night
        } else if now >= sunrise.addingTimeInterval(-twilightOffset) && now < sunrise.addingTimeInterval(twilightOffset) {
            currentSkyCondition = .sunrise
        } else if now >= sunset.addingTimeInterval(-twilightOffset) && now <= sunset.addingTimeInterval(twilightOffset) {
            currentSkyCondition = .sunset
        } else if now >= sunrise.addingTimeInterval(twilightOffset) && now < sunset.addingTimeInterval(-twilightOffset) {
            currentSkyCondition = .daylight
        } else {
            if now < sunrise { currentSkyCondition = .night }
            else if now > sunset { currentSkyCondition = .night }
            else { currentSkyCondition = .daylight }
        }
        print("🌅 SunViewModel: Sky condition updated to: \(currentSkyCondition)")
    }
    
    func updateScheduledNotifications() {
        NotificationScheduler.shared.cancelAllNotifications() // Clear old notifications first
        
        guard appSettings.notificationsEnabled else {
            print("Notifications are disabled in settings. No new notifications will be scheduled.")
            return
        }
        
        let city = solarInfo.city
        
        // Sunrise Alert
        if appSettings.sunriseAlert {
            let sunriseTitle = "Sunrise approaching in \(city)!"
            let sunriseBody = "Good morning! The sun will rise soon."
            NotificationScheduler.shared.scheduleNotification(identifier: "sunrise_alert", title: sunriseTitle, body: sunriseBody, date: solarInfo.sunrise)
        }
        
        // Sunset Alert
        if appSettings.sunsetAlert {
            let sunsetTitle = "Sunset approaching in \(city)!"
            let sunsetBody = "Get ready for the beautiful sunset colors."
            NotificationScheduler.shared.scheduleNotification(identifier: "sunset_alert", title: sunsetTitle, body: sunsetBody, date: solarInfo.sunset)
        }
        
        // High UV Alert
        if appSettings.highUVAlert {
            // Find the soonest high UV time (e.g., first hour with UV index >= 6)
            // For simplicity, this example uses the daily max UV and schedules it for an hour before solar noon if it's high.
            // A more robust solution would iterate through `solarInfo.hourlyUVData`.
            
            let uvThreshold = 6 // Define your "high UV" threshold
            if solarInfo.uvIndex >= uvThreshold {
                // Let's schedule it an hour before it's expected to be very high,
                // or at a peak time if available from hourly data.
                // This is a simplified example: notifies 1 hour before solar noon if daily max UV is high.
                if let noonNotificationTime = Calendar.current.date(byAdding: .hour, value: -1, to: solarInfo.solarNoon) {
                    let highUVTitle = "High UV Alert for \(city)!"
                    let highUVBody = "UV Index is expected to be high (\(solarInfo.uvIndex)). Protect your skin!"
                    NotificationScheduler.shared.scheduleUVNotification(identifier: "high_uv_alert", title: highUVTitle, body: highUVBody, date: noonNotificationTime, uvIndex: solarInfo.uvIndex, threshold: uvThreshold)
                }
            }
            // A more advanced implementation for High UV:
            // Iterate `solarInfo.hourlyUVData`
            if let firstHighUVHour = solarInfo.hourlyUVData.first(where: { $0.uvIndex >= Double(uvThreshold) && $0.time > Date() }) {
                let highUVTitle = "High UV Alert for \(city)!"
                let highUVBody = "UV Index will reach \(Int(firstHighUVHour.uvIndex.rounded())) at \(formatTime(firstHighUVHour.time)). Protect your skin!"
                // Schedule it slightly before, e.g., 30 minutes
                if let notificationTime = Calendar.current.date(byAdding: .minute, value: -30, to: firstHighUVHour.time) {
                    NotificationScheduler.shared.scheduleUVNotification(identifier: "high_uv_alert_\(firstHighUVHour.id)", title: highUVTitle, body: highUVBody, date: notificationTime, uvIndex: Int(firstHighUVHour.uvIndex.rounded()), threshold: uvThreshold)
                }
            }
        }
    }

    private func calculateSunAltitude(latitude: Double, date: Date, timezoneIdentifier: String?) -> Double {
        guard let tzId = timezoneIdentifier else { return 0.0 }
        return SunPositionCalculator.calculateSunPosition(date: date, latitude: latitude, longitude: self.solarInfo.longitude ?? 0.0, timezoneIdentifier: tzId)?.altitude ?? 0.0
    }

    private func calculateSunAzimuth(latitude: Double, date: Date, timezoneIdentifier: String?) -> Double {
        guard let tzId = timezoneIdentifier else { return 0.0 }
        return SunPositionCalculator.calculateSunPosition(date: date, latitude: latitude, longitude: self.solarInfo.longitude ?? 0.0, timezoneIdentifier: tzId)?.azimuth ?? 0.0
    }
    
    func refreshSolarDataForCurrentCity() {
        Task {
            await updateSolarDataForCity(name: solarInfo.city, latitude: solarInfo.latitude, longitude: solarInfo.longitude, explicitTimezoneIdentifier: solarInfo.timezoneIdentifier)
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestLocationPermission()
    }
}
