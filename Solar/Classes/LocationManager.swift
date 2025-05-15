//
//  LocationManager.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import CoreData
import CoreLocation
import Combine

enum LocationError: Error, LocalizedError {
    case authorizationDenied
    case authorizationRestricted
    case unknownAuthorizationStatus
    case locationNotFound
    case reverseGeocodingFailed(Error?)
    case clError(Error)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Location access was denied. Please enable it in Settings."
        case .authorizationRestricted:
            return "Location access is restricted on this device."
        case .unknownAuthorizationStatus:
            return "Location authorization status is unknown."
        case .locationNotFound:
            return "Could not determine your current location."
        case .reverseGeocodingFailed:
            return "Could not determine place name for the location."
        case .clError(let error):
            return error.localizedDescription
        }
    }
}


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastKnownLocation: CLLocation?
    @Published var currentPlacemark: CLPlacemark?
    @Published var isFetchingLocation: Bool = false
    @Published var error: LocationError? = nil

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var statusString: String {
        switch authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .authorizedWhenInUse: return "Authorized When In Use"
        case .authorizedAlways: return "Authorized Always"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        @unknown default: return "Unknown"
        }
    }

    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestCurrentLocation() {
        error = nil // Clear previous errors
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            if authorizationStatus == .denied {
                self.error = .authorizationDenied
            } else if authorizationStatus == .restricted {
                self.error = .authorizationRestricted
            } else if authorizationStatus == .notDetermined {
                requestLocationPermission() // Prompt will trigger didChangeAuthorization
                // Wait for user response, ViewModel should observe authorizationStatus
            } else {
                self.error = .unknownAuthorizationStatus
            }
            isFetchingLocation = false
            return
        }
        
        isFetchingLocation = true
        print("📍 LocationManager: Requesting current location...")
        manager.requestLocation() // For one-time location update
    }
    
    // Asynchronous location request
    func fetchLocation() async throws -> CLLocation {
        isFetchingLocation = true
        error = nil
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            requestCurrentLocation() // Will use the continuation if permission allows
            // Implement a timeout if desired
        }
    }


    // MARK: - CLLocationManagerDelegate
    // Use this delegate method for iOS 14+ for authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { // Ensure UI updates on main thread
            self.authorizationStatus = manager.authorizationStatus
            print("📍 LocationManager: Authorization status changed to: \(self.statusString)")

            switch self.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.error = nil
                // If a continuation was waiting for permission, it will be handled by didUpdateLocations or didFailWithError
                // ViewModel can also react to status change to re-trigger a fetch if needed.
                break
            case .denied:
                self.isFetchingLocation = false
                self.lastKnownLocation = nil
                self.currentPlacemark = nil
                self.error = .authorizationDenied
                self.locationContinuation?.resume(throwing: LocationError.authorizationDenied)
                self.locationContinuation = nil
            case .restricted:
                self.isFetchingLocation = false
                self.lastKnownLocation = nil
                self.currentPlacemark = nil
                self.error = .authorizationRestricted
                self.locationContinuation?.resume(throwing: LocationError.authorizationRestricted)
                self.locationContinuation = nil
            case .notDetermined:
                // Waiting for user input
                break
            @unknown default:
                self.isFetchingLocation = false
                self.error = .unknownAuthorizationStatus
                self.locationContinuation?.resume(throwing: LocationError.unknownAuthorizationStatus)
                self.locationContinuation = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            if let continuation = self.locationContinuation {
                continuation.resume(throwing: LocationError.locationNotFound)
                self.locationContinuation = nil
            }
            self.error = .locationNotFound
            self.isFetchingLocation = false
            return
        }
        
        self.lastKnownLocation = location
        print("📍 LocationManager: Location updated: \(location.coordinate)")
        
        if let continuation = self.locationContinuation {
            continuation.resume(returning: location)
            self.locationContinuation = nil
        }

        // Reverse geocode the new location
        reverseGeocode(location: location)
        // isFetchingLocation will be set to false after geocoding finishes or fails
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Failed to get location: \(error.localizedDescription)")
        self.isFetchingLocation = false
        self.error = .clError(error)
        
        if let continuation = self.locationContinuation {
            continuation.resume(throwing: error)
            self.locationContinuation = nil
        }
        self.currentPlacemark = nil // Clear placemark on location failure
    }

    private func reverseGeocode(location: CLLocation) {
        // Ensure geocoding doesn't run if already in progress for the same location
        // For simplicity, we'll just proceed. Consider cancelling previous operations if needed.
        
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            DispatchQueue.main.async { // Ensure UI updates on main thread
                self.isFetchingLocation = false // Geocoding is the last step of "fetching"
                if let error = error {
                    print("❌ LocationManager: Reverse geocoding failed: \(error.localizedDescription)")
                    self.currentPlacemark = nil
                    self.error = .reverseGeocodingFailed(error)
                    return
                }
                
                if let placemark = placemarks?.first {
                    self.currentPlacemark = placemark
                    print("📍 LocationManager: Placemark found: \(placemark.locality ?? placemark.name ?? "N/A")")
                    self.error = nil // Clear previous errors if geocoding is successful
                } else {
                    print("⚠️ LocationManager: No placemark found for the location.")
                    self.currentPlacemark = nil
                    self.error = .reverseGeocodingFailed(nil)
                }
            }
        }
    }
}
