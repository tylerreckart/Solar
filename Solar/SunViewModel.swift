//
//  SunViewModel.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import Foundation
import Combine
import CoreLocation

class SunViewModel: ObservableObject {
    @Published var solarInfo: SolarInfo
    @Published var isLoadingLocation: Bool = false
    @Published var isLoadingSolarData: Bool = false
    @Published var errorMessage: String? = nil // Consolidated error message

    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // Example: "5:45 AM"
        return formatter
    }()

    private let locationManager = LocationManager()
    private let solarAPIService = SolarAPIService()
    private var cancellables = Set<AnyCancellable>()

    init(initialCity: String = "Philadelphia", initialLat: Double? = 39.9526, initialLon: Double? = -75.1652) {
        self.solarInfo = SolarInfo.placeholder(city: initialCity, lat: initialLat, lon: initialLon)
        setupBindings()
        
        // Attempt to load data for initial city if lat/lon are available
        if let lat = initialLat, let lon = initialLon {
            Task {
                await updateSolarDataForCity(name: initialCity, latitude: lat, longitude: lon)
            }
        } else if locationManager.locationStatus == .authorizedWhenInUse || locationManager.locationStatus == .authorizedAlways {
            // requestCurrentLocationData() // Optionally auto-request on init if no initial lat/lon
        }
    }
    
    private func setupBindings() {
        locationManager.$placemark
            .receive(on: DispatchQueue.main)
            .sink { [weak self] placemark in
                guard let self = self else { return }
                if let placemark = placemark {
                    let cityName = placemark.locality ?? placemark.name ?? "Current Location"
                    let lat = placemark.location?.coordinate.latitude
                    let lon = placemark.location?.coordinate.longitude
                    
                    // Update solar data based on new location
                    Task { // Call async function from sync context
                        await self.updateSolarDataForCity(name: cityName, latitude: lat, longitude: lon)
                    }
                    self.errorMessage = nil
                } else if !self.locationManager.isLoading {
                    if self.locationManager.locationStatus == .denied || self.locationManager.locationStatus == .restricted {
                        self.errorMessage = "Location access denied. Please enable in Settings."
                    }
                }
            }
            .store(in: &cancellables)

        locationManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoadingLocation, on: self)
            .store(in: &cancellables)
            
        locationManager.$locationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .denied || status == .restricted {
                    self.isLoadingLocation = false
                    self.errorMessage = "Location access is \(self.locationManager.statusString). Enable in Settings to use current location."
                } else if status == .authorizedAlways || status == .authorizedWhenInUse {
                    // If permission is granted and we don't have a city or have the default, try fetching current location.
                    if self.solarInfo.city == "Philadelphia" && self.solarInfo.latitude == 39.9526 { // Check if it's still the default
                        // self.requestCurrentLocationData() // Consider if this auto-fetch is desired
                    }
                    self.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    // Called when a city is selected by name (e.g., from saved list or search)
    func updateCityByName(name: String) {
        print("City updated by name to: \(name)")
        self.isLoadingSolarData = true // Indicate loading
        self.errorMessage = nil
        
        // Step 1: Geocode city name to get coordinates
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(name) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not find coordinates for \(name): \(error.localizedDescription)"
                    self.isLoadingSolarData = false
                }
                return
            }
            
            guard let placemark = placemarks?.first, let location = placemark.location else {
                DispatchQueue.main.async {
                    self.errorMessage = "No coordinates found for \(name)."
                    self.isLoadingSolarData = false
                }
                return
            }
            
            // Step 2: Update solar data with fetched coordinates
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            Task { // Call async function
                await self.updateSolarDataForCity(name: name, latitude: lat, longitude: lon)
            }
        }
    }
    
    // Central function to update solar info, now async
    func updateSolarDataForCity(name: String, latitude: Double?, longitude: Double?) async {
        DispatchQueue.main.async { // Ensure UI updates are on main thread
            self.solarInfo.city = name
            self.solarInfo.latitude = latitude
            self.solarInfo.longitude = longitude
            self.isLoadingSolarData = true
            self.errorMessage = nil
        }

        guard let lat = latitude, let lon = longitude else {
            DispatchQueue.main.async {
                self.errorMessage = "Latitude/Longitude not available for \(name)."
                self.isLoadingSolarData = false
            }
            return
        }

        print("Attempting to fetch solar data for \(name) at Lat: \(lat), Lon: \(lon)")
        do {
            let apiResponse = try await solarAPIService.fetchSolarData(latitude: lat, longitude: lon)
            
            // Process API response
            guard let firstSunriseStr = apiResponse.daily.sunrise.first,
                  let firstSunsetStr = apiResponse.daily.sunset.first,
                  let firstDateStr = apiResponse.daily.time.first else {
                DispatchQueue.main.async {
                    self.errorMessage = "API response missing essential data for \(name)."
                    self.isLoadingSolarData = false
                }
                return
            }

            guard let sunriseDate = solarAPIService.parseISOString(firstSunriseStr),
                  let sunsetDate = solarAPIService.parseISOString(firstSunsetStr) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not parse sunrise/sunset times for \(name)."
                    self.isLoadingSolarData = false
                }
                return
            }
            
            let uvMax = apiResponse.daily.uv_index_max.first ?? nil // Can be nil from API

            // Calculate solar noon
            let solarNoonDate = Date(timeInterval: (sunsetDate.timeIntervalSince(sunriseDate) / 2), since: sunriseDate)
            
            // Determine UV category (simple example)
            let uvIndexInt = Int(uvMax ?? 0.0)
            var uvCategory = "Low"
            if uvIndexInt >= 11 { uvCategory = "Extreme" }
            else if uvIndexInt >= 8 { uvCategory = "Very High" }
            else if uvIndexInt >= 6 { uvCategory = "High" }
            else if uvIndexInt >= 3 { uvCategory = "Moderate" }

            // Update SolarInfo on the main thread
            DispatchQueue.main.async {
                self.solarInfo.sunrise = sunriseDate
                self.solarInfo.sunset = sunsetDate
                self.solarInfo.solarNoon = solarNoonDate
                self.solarInfo.uvIndex = uvIndexInt
                self.solarInfo.uvIndexCategory = uvCategory
                
                // Update currentDate to reflect the date of the fetched data
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                self.solarInfo.currentDate = dateFormatter.date(from: firstDateStr) ?? Date() // Fallback to now

                self.isLoadingSolarData = false
                self.errorMessage = nil
                print("Successfully updated solar data for \(name). Sunrise: \(self.formatTime(sunriseDate)), Sunset: \(self.formatTime(sunsetDate))")
            }

        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch solar data for \(name): \(error.localizedDescription)"
                self.isLoadingSolarData = false
                print("Error fetching solar data: \(error)")
                // Optionally, revert to placeholder data or keep old data
                // self.solarInfo = SolarInfo.placeholder(city: name, lat: lat, lon: lon) // Revert to placeholder on error
            }
        }
    }

    func requestCurrentLocationData() {
        self.errorMessage = nil
        locationManager.requestLocation() // isLoadingLocation will be updated by locationManager binding
    }
}
