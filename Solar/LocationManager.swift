//
//  LocationManager.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import CoreData
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var locationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var isLoading: Bool = false // To indicate when fetching location/geocoding

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Accuracy for city level is fine
        // Get initial authorization status
        self.locationStatus = locationManager.authorizationStatus
    }

    var statusString: String {
        guard let status = locationStatus else {
            return "unknown"
        }
        switch status {
        case .notDetermined: return "notDetermined"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .authorizedAlways: return "authorizedAlways"
        case .restricted: return "restricted"
        case .denied: return "denied"
        @unknown default: return "unknown"
        }
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        // Ensure we have permission before requesting.
        // If not determined, it means the prompt hasn't been shown or user hasn't responded.
        // If denied/restricted, we can't request.
        guard let currentStatus = self.locationStatus else {
            print("Location status is nil, cannot request location.")
            return
        }

        if currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways {
            isLoading = true
            locationManager.requestLocation() // For one-time location update
        } else if currentStatus == .notDetermined {
            print("Location permission not determined. Requesting permission first.")
            requestLocationPermission() // This will trigger didChangeAuthorization, then location can be requested if granted.
        } else {
            print("Location permission not granted (denied/restricted). Status: \(statusString)")
            // Optionally, guide user to settings.
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // This is now 'locationManagerDidChangeAuthorization' in newer iOS versions.
        // For compatibility, or if using older delegate methods, this is fine.
        // Or use: func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        //    self.locationStatus = manager.authorizationStatus (or just 'status' if that's the new var name)
        self.locationStatus = status // Update published status
        print("Location status changed: \(statusString)")
        
        // If permission was just granted, and we were waiting to request location:
        if (status == .authorizedWhenInUse || status == .authorizedAlways) && isLoading {
             // If isLoading was true because we were waiting for permission after a requestLocation call.
             // However, it's often better to let the calling code (e.g., ViewModel) decide to re-request.
             // For simplicity here, if we are in a loading state (implying a request was pending permission), try again.
            print("Permission granted, re-attempting location request.")
            // locationManager.requestLocation() // Be careful about request loops.
                                            // Better to handle this in the ViewModel or UI logic.
        } else if status == .denied || status == .restricted {
            isLoading = false // Stop loading if permission is denied/restricted
            self.placemark = nil // Clear placemark if permission is lost
        }
    }
    
    // Use this delegate method for iOS 14+ for authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.locationStatus = manager.authorizationStatus
        print("Location status changed (iOS 14+): \(statusString)")
        
        if (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
            // If permission is granted, the ViewModel can decide to fetch location.
            // If isLoading was true because we were waiting for permission after a requestLocation call:
            // This logic is a bit tricky here, as the request might have been initiated by the ViewModel.
            // The ViewModel should ideally react to the status change.
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            isLoading = false
            self.placemark = nil
        }
    }


    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLoading = false
            return
        }
        self.lastLocation = location
        print("Location updated: \(location)")
        reverseGeocode(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        print("Failed to get location: \(error.localizedDescription)")
        // Handle errors, e.g., show an alert to the user.
        // Also clear placemark if location fails
        self.placemark = nil
    }

    private func reverseGeocode(location: CLLocation) {
        // Ensure geocoding doesn't run if already in progress for the same location or if no location
        // This simple check might not be enough for rapid updates.
        // Consider cancelling previous geocode operations if a new location comes in quickly.
        
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            // Ensure self is still available
            guard let self = self else { return }
            
            // Always set isLoading to false once geocoding finishes or fails
            // This should be inside the completion handler
            // self.isLoading = false // Moved here from outside the closure in previous version

            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                self.placemark = nil // Clear previous placemark on error
                self.isLoading = false // Ensure loading is false on error
                return
            }
            self.placemark = placemarks?.first
            if let placemark = self.placemark {
                 print("Placemark found: \(placemark.locality ?? placemark.name ?? "N/A"), \(placemark.country ?? "N/A")")
            } else {
                print("No placemark found for the location.")
            }
            self.isLoading = false // Ensure loading is false on success as well
        }
    }
}
