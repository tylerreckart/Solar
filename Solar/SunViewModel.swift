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
                // This is part of the "Use Current Location" flow
                if self.isFetchingLocationDetails {
                    if let placemark = placemark, let location = placemark.location {
                        let cityName = placemark.locality ?? placemark.name ?? "Current Location"
                        // Store the timezone from CLPlacemark if available
                        let clTimezoneIdentifier = placemark.timeZone?.identifier
                        
                        Task {
                            // Pass clTimezoneIdentifier to be potentially stored if API doesn't provide one
                            // (though Open-Meteo usually does)
                            await self.updateSolarDataForCity(name: cityName,
                                                              latitude: location.coordinate.latitude,
                                                              longitude: location.coordinate.longitude,
                                                              explicitTimezoneIdentifier: clTimezoneIdentifier)
                        }
                    } else if self.locationManager.error != nil {
                         self.dataLoadingState = .error(message: self.locationManager.error?.localizedDescription ?? "Failed to get location details.")
                    }
                    self.isFetchingLocationDetails = false
                }
            }
            .store(in: &cancellables)
        
        // Other bindings remain similar...
        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                print("☀️ SunViewModel: Location auth status changed to \(self.locationManager.statusString)")
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                     if self.solarInfo.city == "Loading..." || self.solarInfo.city == "Philadelphia" {
                        self.requestSolarDataForCurrentLocation()
                    }
                case .denied:
                    self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription)
                case .restricted:
                     self.dataLoadingState = .error(message: LocationError.authorizationRestricted.localizedDescription)
                case .notDetermined:
                    self.dataLoadingState = .idle
                default:
                    self.dataLoadingState = .error(message: "Unknown location permission status.")
                }
            }
            .store(in: &cancellables)
            
        locationManager.$isFetchingLocation
            .receive(on: DispatchQueue.main)
            .assign(to: \.isFetchingLocationDetails, on: self)
            .store(in: &cancellables)

        locationManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self = self, let error = error else { return }
                if self.isFetchingLocationDetails || self.dataLoadingState_isLoading() {
                    self.dataLoadingState = .error(message: error.localizedDescription)
                    self.isFetchingLocationDetails = false
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
        // ... (same as before)
        guard !isFetchingLocationDetails else { return }
        print("☀️ SunViewModel: Requesting solar data for current location.")
        isFetchingLocationDetails = true
        dataLoadingState = .loading
        locationManager.requestCurrentLocation()
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

            self.solarInfo = SolarInfo(
                city: name,
                latitude: lat,
                longitude: lon,
                currentDate: currentDate,
                sunrise: sunriseDate,
                sunset: sunsetDate,
                solarNoon: solarNoonDate,
                timezoneIdentifier: locationTimezoneIdentifier, // Store the fetched timezone identifier
                hourlyUVData: parsedHourlyUV,
                currentAltitude: calculateSunAltitude(latitude: lat, date: Date(), timezoneIdentifier: locationTimezoneIdentifier),
                currentAzimuth: calculateSunAzimuth(latitude: lat, date: Date(), timezoneIdentifier: locationTimezoneIdentifier),
                uvIndex: uvIndexInt,
                uvIndexCategory: uvCategory,
                weatherCode: currentHourWeatherCode,
                cloudCover: currentHourCloudCover
            )
            
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

    // Sun position calculations need to know the local solar time at the location.
    // One way is to use the location's timezone to determine the local hour for `date`.
    private func calculateSunAltitude(latitude: Double, date: Date, timezoneIdentifier: String?) -> Double {
        // This still needs a proper astronomical library.
        // For a slightly more contextual placeholder, we could adjust "progress"
        // based on the local time at the location.
        let progress = solarInfo.sunProgress // This progress is already correct (universal time vs universal event times)
        let maxAltitude = 70.0
        let altitude = maxAltitude * sin(progress * .pi)
        return max(0, altitude)
    }

    private func calculateSunAzimuth(latitude: Double, date: Date, timezoneIdentifier: String?) -> Double {
        let progress = solarInfo.sunProgress
        let azimuth = 90 + (progress * 180)
        return azimuth
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
