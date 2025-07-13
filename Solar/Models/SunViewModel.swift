import Foundation
import Combine
import CoreLocation
import UserNotifications
import HappyPath
import WidgetKit

@MainActor
class SunViewModel: ObservableObject {
    @Published var solarInfo: SolarInfo
    @Published var currentSkyCondition: SkyCondition = .daylight
    @Published var dataLoadingState: DataLoadingState = .idle
    
    @Published var isFetchingLocationDetails: Bool = false
    @Published var isGeocodingCity: Bool = false

    @Published var shouldDismissActiveSheets: Bool = false

    private let appSettings = AppSettings.shared
    private let locationManager = LocationManager()
    private let solarAPIService = SolarAPIService()
    private let sharedDataManager = SharedDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var manualCitySelectionInProgressCount = 0

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }()

    init() {
        self.solarInfo = SolarInfo.placeholder()
        
        setupBindings() // Setup observers early.

        // Determine initial data load strategy AFTER bindings are set up and appSettings is ready.
        if appSettings.useCurrentLocation {
            // If using current location, check current authorization status.
            let authStatus = locationManager.authorizationStatus
            print("☀️ SunViewModel: Initializing with 'Use Current Location' ON. Current auth status: \(locationManager.statusString)")
            
            switch authStatus {
            case .notDetermined:
                // If not determined, set loading state and request permission.
                // The permission result will trigger the data fetch via the locationManager.$authorizationStatus sink.
                self.isFetchingLocationDetails = true
                self.dataLoadingState = .loading
                locationManager.requestLocationPermission()
            case .authorizedWhenInUse, .authorizedAlways:
                // If already authorized, request current location immediately.
                requestSolarDataForCurrentLocation()
            case .denied, .restricted:
                // If denied or restricted, show an error and set placeholder city.
                self.solarInfo = SolarInfo.placeholder(city: "Location Denied")
                self.dataLoadingState = .error(message: "Location access was denied. Please enable it in Settings or turn off 'Use Current Location'.")
            @unknown default:
                self.solarInfo = SolarInfo.placeholder(city: "Unknown Status")
                self.dataLoadingState = .error(message: "Unknown location permission status.")
            }
        } else {
            // If not using current location, try to load the last saved city from UserDefaults.
            let defaults = UserDefaults.standard
            if let cityName = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityName),
               let latitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLatitude) as? Double,
               let longitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLongitude) as? Double {
                let timezoneId = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
                
                // Sync existing saved city data to SharedDataManager for widgets
                sharedDataManager.lastSelectedCityName = cityName
                sharedDataManager.lastSelectedCityLatitude = latitude
                sharedDataManager.lastSelectedCityLongitude = longitude
                sharedDataManager.lastSelectedCityTimezoneId = timezoneId
                print("✅ SunViewModel: Synced existing saved city '\(cityName)' to SharedDataManager during init")
                sharedDataManager.printDebugInfo()
                
                Task { @MainActor in
                    await self.updateSolarDataForCity(name: cityName, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneId)
                }
            } else {
                // If no last saved city and 'Use Current Location' is OFF, prompt the user to search.
                self.solarInfo = SolarInfo.placeholder(city: "Select a City")
                self.dataLoadingState = .error(message: "Please search for a city.")
            }
        }
    }
    
    private func setupBindings() {
        locationManager.$currentPlacemark
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] validPlacemark in
                guard let self = self else { return }
                if self.isFetchingLocationDetails { // Only act if we were actively fetching current location
                    if let location = validPlacemark.location {
                        let cityName = validPlacemark.locality ?? validPlacemark.name ?? "Current Location"
                        let clTimezoneIdentifier = validPlacemark.timeZone?.identifier
                        print("📍 SunViewModel (Placemark Sink): Valid placemark received for '\(cityName)'. Updating solar data.")
                        Task {
                            await self.updateSolarDataForCity(name: cityName,
                                                              latitude: location.coordinate.latitude,
                                                              longitude: location.coordinate.longitude,
                                                              explicitTimezoneIdentifier: clTimezoneIdentifier)
                            // Reset isFetchingLocationDetails once data is processed
                            self.isFetchingLocationDetails = false
                        }
                    } else {
                        print("❌ SunViewModel (Placemark Sink): Valid placemark received but location is nil.")
                        self.dataLoadingState = .error(message: "Placemark found, but location coordinates are missing.")
                        self.isFetchingLocationDetails = false
                    }
                }
            }
            .store(in: &cancellables)
        
        appSettings.$useCurrentLocation
            .dropFirst() // Ignore initial value set during init
            .receive(on: DispatchQueue.main)
            .sink { [weak self] useCurrent in
                guard let self = self else { return }
                print("☀️ SunViewModel: 'Use Current Location' setting changed to: \(useCurrent)")
                if useCurrent {
                    // User toggled ON 'Use Current Location'.
                    let authStatus = self.locationManager.authorizationStatus
                    if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                        print("☀️ SunViewModel: User toggled ON 'Use Current Location' and permission granted. Requesting current location data.")
                        self.requestSolarDataForCurrentLocation()
                    } else if authStatus == .notDetermined {
                        print("☀️ SunViewModel: User toggled ON 'Use Current Location'. Location permission not determined, requesting permission.")
                        self.isFetchingLocationDetails = true
                        self.dataLoadingState = .loading
                        self.locationManager.requestLocationPermission() // This will trigger locationManager.$authorizationStatus sink
                    } else { // denied or restricted
                        self.solarInfo = SolarInfo.placeholder(city: "Location Denied")
                        self.dataLoadingState = .error(message: "Location access was denied. Please enable it in Settings or turn off 'Use Current Location'.")
                    }
                } else {
                    // User toggled OFF 'Use Current Location'.
                    if self.manualCitySelectionInProgressCount > 0 {
                        print("☀️ SunViewModel: 'Use Current Location' turned OFF, but manualCitySelectionInProgressCount (\(self.manualCitySelectionInProgressCount)) > 0. Letting initiated city selection proceed.")
                    } else {
                        print("☀️ SunViewModel: 'Use Current Location' turned OFF. Loading last persisted city if available.")
                        let defaults = UserDefaults.standard
                        if let cityName = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityName),
                           let latitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLatitude) as? Double,
                           let longitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLongitude) as? Double {
                            let timezoneId = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
                            Task { @MainActor in
                                await self.updateSolarDataForCity(name: cityName, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneId)
                            }
                        } else {
                            print("☀️ SunViewModel: No last saved city and 'Use CurrentLocation' is OFF. Prompting user to search.")
                            self.solarInfo = SolarInfo.placeholder(city: "Select a City")
                            self.dataLoadingState = .error(message: "Please search for a city.")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        Publishers.MergeMany(
            appSettings.$notificationsEnabled.dropFirst().eraseToAnyPublisher(),
            appSettings.$sunriseAlert.dropFirst().eraseToAnyPublisher(),
            appSettings.$sunsetAlert.dropFirst().eraseToAnyPublisher(),
            appSettings.$highUVAlert.dropFirst().eraseToAnyPublisher()
        )
        .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            print("🗓️ Notifications: Settings changed, updating scheduled notifications.")
            self?.updateScheduledNotifications()
        }
        .store(in: &cancellables)

        locationManager.$authorizationStatus
            .dropFirst() // Ignore initial value set during init
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                print("☀️ SunViewModel: Location auth status changed (observer) to \(self.locationManager.statusString)")
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    if self.appSettings.useCurrentLocation { // Only fetch if 'Use Current Location' is ON
                        print("☀️ SunViewModel (Auth Observer): Auth is authorized, 'Use Current Location' is ON. Requesting current location.")
                        self.isFetchingLocationDetails = false
                        self.requestSolarDataForCurrentLocation()
                    } else {
                         // If 'Use Current Location' is OFF, and auth changes, no action needed here regarding data fetch
                        self.isFetchingLocationDetails = false // Ensure loading state is false if permission was granted but we're not using it
                        self.dataLoadingState = .success // Or previous state if not an error
                        print("☀️ SunViewModel (Auth Observer): Permission granted, but 'Use Current Location' is OFF. No data fetch initiated.")
                    }
                case .denied:
                    self.isFetchingLocationDetails = false
                    self.locationManager.currentPlacemark = nil
                    self.locationManager.error = .authorizationDenied // Set error in LocationManager itself
                    if self.appSettings.useCurrentLocation {
                        print("☀️ SunViewModel (Auth Observer): Auth denied. Setting error state.")
                        self.solarInfo = SolarInfo.placeholder(city: "Location Denied")
                        self.dataLoadingState = .error(message: LocationError.authorizationDenied.localizedDescription + " Enable in Settings or turn off 'Use Current Location'.")
                    } else {
                         print("☀️ SunViewModel (Auth Observer): Permission denied, but 'Use Current Location' is OFF. No data fetch initiated, current city preserved.")
                    }
                case .restricted:
                    self.isFetchingLocationDetails = false
                    self.locationManager.lastKnownLocation = nil
                    self.locationManager.currentPlacemark = nil
                    self.locationManager.error = .authorizationRestricted // Set error in LocationManager itself
                    if self.appSettings.useCurrentLocation {
                        print("☀️ SunViewModel (Auth Observer): Auth restricted. Setting error state.")
                        self.solarInfo = SolarInfo.placeholder(city: "Location Restricted")
                        self.dataLoadingState = .error(message: LocationError.authorizationRestricted.localizedDescription)
                    } else {
                        print("☀️ SunViewModel (Auth Observer): Permission restricted, but 'Use Current Location' is OFF. No data fetch initiated, current city preserved.")
                    }
                case .notDetermined:
                    // Waiting for user input. If isFetchingLocationDetails is true, it means we're expecting a prompt.
                    // Do nothing here to avoid prematurely setting an error state if permission is still being decided.
                    print("☀️ SunViewModel (Auth Observer): Auth is .notDetermined. Awaiting user response.")
                    break
                @unknown default:
                    self.isFetchingLocationDetails = false
                    self.locationManager.error = .unknownAuthorizationStatus // Set error in LocationManager itself
                    if self.appSettings.useCurrentLocation {
                        self.dataLoadingState = .error(message: LocationError.unknownAuthorizationStatus.localizedDescription)
                    }
                }
            }
            .store(in: &cancellables)

        locationManager.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedError in
                guard let self = self else { return }
                // Only process errors if we were actively trying to fetch location and it's not a transient 'locationUnknown' error.
                if self.isFetchingLocationDetails {
                    if case .clError(let underlyingError) = receivedError {
                        let nsError = underlyingError as NSError
                        // Ignore transient kCLErrorLocationUnknown if data already exists, or it's not a critical startup error.
                        if nsError.domain == kCLErrorDomain && nsError.code == CLError.Code.locationUnknown.rawValue {
                            print("⚠️ SunViewModel (Error Sink): Ignored transient kCLErrorLocationUnknown. Current isFetchingLocationDetails: \(self.isFetchingLocationDetails)")
                            // If we already have data, and it's just a transient unknown error, don't set error state.
                            if self.dataLoadingState == .loading { // Only revert if we're stuck in loading by this error
                                self.dataLoadingState = .success // Revert to success or current state if data exists
                            }
                            self.isFetchingLocationDetails = false
                            return // Do not process this error further
                        }
                    }
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
        // This function is called when current location data is explicitly needed,
        // either due to appSettings toggle or location auth status change.
        guard !isFetchingLocationDetails else {
            print("☀️ SunViewModel: Already fetching location details for current location (from requestSolarDataForCurrentLocation).")
            return
        }
        
        print("☀️ SunViewModel: Requesting current location data based on current authorization.")
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.isFetchingLocationDetails = true
            self.dataLoadingState = .loading
            locationManager.requestCurrentLocation() // Request one-time location update
        case .notDetermined:
            // This case should ideally be handled by the auth status sink or appSettings sink.
            // If we somehow get here, request permission again, which will trigger the auth status sink.
            self.isFetchingLocationDetails = true
            self.dataLoadingState = .loading
            locationManager.requestLocationPermission()
        case .denied:
            self.dataLoadingState = .error(message: "Location access was denied. Please enable it in Settings or turn off 'Use Current Location'.")
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
            // Set shouldDismissActiveSheets to true when a city is manually selected
            self.shouldDismissActiveSheets = true

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
        guard !isGeocodingCity && manualCitySelectionInProgressCount == 0 else {
            print("☀️ SunViewModel: GeocodeAndSelectCity skipped for '\(name)', already geocoding or manual selection in progress.")
            return
        }
        print("☀️ SunViewModel: Geocoding and selecting city: \(name)")
        
        await MainActor.run {
            // Set shouldDismissActiveSheets to true when geocoding a new city
            self.shouldDismissActiveSheets = true

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
    
    private func updateSolarDataForCity(name: String, latitude: Double?, longitude: Double?, explicitTimezoneIdentifier: String? = nil, suppressErrors: Bool = false) async {
        dataLoadingState = .loading

        guard let lat = latitude, let lon = longitude else {
            if !suppressErrors {
                dataLoadingState = .error(message: "Latitude/Longitude not available for \(name).")
            }
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
                if !suppressErrors {
                    dataLoadingState = .error(message: "Could not parse date/time strings for \(name).")
                }
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
                        if let uvIndices = hourlyUVIndices, i < uvIndices.count, let uvValueOptional = uvIndices[i], let date = solarAPIService.parseDateTimeString(hourlyTimes[i], timezoneIdentifier: locationTimezoneIdentifier) {
                            if (localCalendar.isDateInToday(date) && date >= now) || date > now {
                                parsedHourlyUV.append(SolarInfo.HourlyUV(time: date, uvIndex: uvValueOptional))
                            }
                        }
                    }
                    parsedHourlyUV = parsedHourlyUV.filter { $0.time >= now }.sorted { $0.time < $1.time }

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
                
                // Also save to shared storage for widgets
                sharedDataManager.lastSelectedCityName = self.solarInfo.city
                if let savedLat = self.solarInfo.latitude, let savedLon = self.solarInfo.longitude {
                    sharedDataManager.lastSelectedCityLatitude = savedLat
                    sharedDataManager.lastSelectedCityLongitude = savedLon
                }
                sharedDataManager.lastSelectedCityTimezoneId = self.solarInfo.timezoneIdentifier
                
                print("✅ SunViewModel: Saved '\(self.solarInfo.city)' as last selected city (since 'Use Current Location' is OFF).")
                sharedDataManager.printDebugInfo()
            } else {
                // Save current location data to shared storage for widgets
                sharedDataManager.currentLocationCity = self.solarInfo.city
                if let lat = self.solarInfo.latitude, let lon = self.solarInfo.longitude {
                    sharedDataManager.currentLocationLatitude = lat
                    sharedDataManager.currentLocationLongitude = lon
                }
                sharedDataManager.currentLocationTimezone = self.solarInfo.timezoneIdentifier
                
                print("✅ SunViewModel: Data updated for current location. Saved current location data for widgets.")
                sharedDataManager.printDebugInfo()
            }
            
            // Always save the useCurrentLocation setting to shared storage
            sharedDataManager.useCurrentLocation = appSettings.useCurrentLocation
            
            // Mark data as updated for widget refresh logic
            sharedDataManager.markDataUpdated()
            
            // Refresh all widgets with updated location data
            refreshAllWidgets()

        } catch {
            print("❌ SunViewModel: Error fetching or parsing solar data for \(name): \(error.localizedDescription)")
            if !suppressErrors {
                var detailedMessage = "Failed to get solar data: \(error.localizedDescription)"
                let nsError = error as NSError
                if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                    detailedMessage += "\n\nReason: \(reason)"
                }
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    detailedMessage += "\n\nDetails: \(underlyingError.localizedDescription) (domain: \(underlyingError.domain), code: \(underlyingError.code))"
                }
                dataLoadingState = .error(message: detailedMessage)
            }
        }
    }

    private func updateSkyCondition() {
        let now = Date()
        guard solarInfo.sunrise != SolarInfo.placeholder().sunrise,
              solarInfo.sunset != SolarInfo.placeholder().sunset else {
            currentSkyCondition = .daylight
            return
        }

        let sunriseThreshold: TimeInterval = 30 * 60
        let sunsetThreshold: TimeInterval = 30 * 60

        if now < solarInfo.sunrise.addingTimeInterval(-sunriseThreshold) {
            currentSkyCondition = .night
        } else if now >= solarInfo.sunrise.addingTimeInterval(-sunriseThreshold) && now <= solarInfo.sunrise.addingTimeInterval(sunriseThreshold) {
            currentSkyCondition = .sunrise
        } else if now > solarInfo.sunrise.addingTimeInterval(sunriseThreshold) && now < solarInfo.sunset.addingTimeInterval(-sunsetThreshold) {
            currentSkyCondition = .daylight
        } else if now >= solarInfo.sunset.addingTimeInterval(-sunsetThreshold) && now <= solarInfo.sunset.addingTimeInterval(sunsetThreshold) {
            currentSkyCondition = .sunset
        } else {
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
                if self.appSettings.notificationsEnabled {
                    print("🗓️ Notifications: System permission denied, but app setting was true. SolarApp should correct this.")
                }
                return
            }

            NotificationScheduler.shared.cancelAllNotifications()

            guard self.appSettings.notificationsEnabled else {
                print("🗓️ Notifications: Master notifications toggle is OFF in AppSettings. All notifications cancelled, skipping new scheduling.")
                return
            }
            
            print("🗓️ Notifications: Master toggle is ON. Proceeding with individual alert checks.")

            let placeholder = SolarInfo.placeholder()
            guard self.solarInfo.sunrise != placeholder.sunrise,
                  self.solarInfo.sunset != placeholder.sunrise, // Check against placeholder value
                  self.solarInfo.city != placeholder.city || self.solarInfo.city == "Current Location"
            else {
                print("🗓️ Notifications: SolarInfo contains placeholder data or invalid city. Skipping scheduling. City: \(self.solarInfo.city)")
                return
            }
            
            let cityName = self.solarInfo.city

            if self.appSettings.sunriseAlert {
                print("🗓️ Notifications: Sunrise alert is ON.")
                let sunriseTime = self.solarInfo.sunrise
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

            if self.appSettings.sunsetAlert {
                print("🗓️ Notifications: Sunset alert is ON.")
                let sunsetTime = self.solarInfo.sunset
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

            if self.appSettings.highUVAlert {
                print("🗓️ Notifications: High UV alert is ON.")
                let highUVThreshold = 6
                var scheduledFirstHighUV = false

                for uvItem in self.solarInfo.hourlyUVData {
                    let uvIndexValue = Int(round(uvItem.uvIndex))
                    let alertTime = uvItem.time

                    if uvIndexValue >= highUVThreshold && alertTime > Date() {
                         if scheduledFirstHighUV { continue }
                        
                        NotificationScheduler.shared.scheduleUVNotification(
                            identifier: "highUVAlert_\(uvItem.id)",
                            title: "High UV Warning!",
                            body: "UV Index in \(cityName) will be \(uvIndexValue) (\(uvItem.uvCategory)) around \(self.formatTime(alertTime)). Protect your skin!",
                            date: alertTime,
                            uvIndex: uvIndexValue,
                            threshold: highUVThreshold
                        )
                        scheduledFirstHighUV = true
                    }
                }
                if !scheduledFirstHighUV && !self.solarInfo.hourlyUVData.filter({ Int(round($0.uvIndex)) >= highUVThreshold && $0.time > Date() }).isEmpty {
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
    
    // This function is for explicit user-initiated refreshes (e.g., pull-to-refresh, retry button).
    func refreshSolarDataForCurrentCity() {
        self.shouldDismissActiveSheets = true // Dismiss sheets on any manual refresh

        guard !isFetchingLocationDetails && !isGeocodingCity && manualCitySelectionInProgressCount == 0 else {
            print("☀️ SunViewModel: Manual refresh skipped, already fetching or processing.")
            return
        }
        
        if appSettings.useCurrentLocation {
            // If 'Use Current Location' is ON, trigger location request.
            // The auth status sink will handle the rest of the flow.
            requestSolarDataForCurrentLocation()
        } else {
            // If 'Use Current Location' is OFF, load the last selected city or prompt.
            let defaults = UserDefaults.standard
            if let cityName = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityName),
               let latitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLatitude) as? Double,
               let longitude = defaults.object(forKey: UserDefaultsKeys.lastSelectedCityLongitude) as? Double {
                let timezoneId = defaults.string(forKey: UserDefaultsKeys.lastSelectedCityTimezoneId)
                Task { @MainActor in
                    await self.updateSolarDataForCity(name: cityName, latitude: latitude, longitude: longitude, explicitTimezoneIdentifier: timezoneId)
                }
            } else {
                // If no last saved city, and user explicitly tries to refresh, prompt them.
                self.solarInfo = SolarInfo.placeholder(city: "Select a City")
                self.dataLoadingState = .error(message: "Please search for a city.")
            }
        }
    }
    
    func requestLocationPermission() { locationManager.requestLocationPermission() }
    
    // MARK: - Widget Management
    
    /// Refreshes all Solar widgets when location data changes
    private func refreshAllWidgets() {
        print("🔄 SunViewModel: Refreshing all widgets with updated data")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
