//
//  SharedDataManager.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import Foundation

/// Manages data sharing between the main app and widget extensions via App Groups
public class SharedDataManager {
    public static let shared = SharedDataManager()
    
    private let suiteName = "group.com.haptic.solar"
    private let userDefaults: UserDefaults
    
    private init() {
        guard let sharedDefaults = UserDefaults(suiteName: suiteName) else {
            print("❌ SharedDataManager (Widget): Failed to create UserDefaults with suite name \(suiteName). App Groups not configured properly!")
            self.userDefaults = UserDefaults.standard
            return
        }
        self.userDefaults = sharedDefaults
        print("✅ SharedDataManager (Widget): Successfully initialized with App Group: \(suiteName)")
        
        // Test if we can read data written by the main app
        let testKey = "widget_test_\(Date().timeIntervalSince1970)"
        userDefaults.set("widget_test_value", forKey: testKey)
        if let testValue = userDefaults.string(forKey: testKey) {
            print("✅ SharedDataManager (Widget): App Group read/write test passed")
        } else {
            print("❌ SharedDataManager (Widget): App Group read/write test failed!")
        }
        userDefaults.removeObject(forKey: testKey)
    }
    
    // MARK: - App Settings
    
    var useCurrentLocation: Bool {
        get {
            return userDefaults.bool(forKey: "useCurrentLocation")
        }
        set {
            userDefaults.set(newValue, forKey: "useCurrentLocation")
            print("🔸 SharedDataManager: useCurrentLocation set to \(newValue)")
        }
    }
    
    // MARK: - Current Location Data
    
    var currentLocationCity: String? {
        get {
            return userDefaults.string(forKey: "currentLocationCity")
        }
        set {
            userDefaults.set(newValue, forKey: "currentLocationCity")
        }
    }
    
    var currentLocationLatitude: Double? {
        get {
            let value = userDefaults.object(forKey: "currentLocationLatitude") as? Double
            return value
        }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: "currentLocationLatitude")
                // Also update timestamp when location data changes
                currentLocationTimestamp = Date()
            } else {
                userDefaults.removeObject(forKey: "currentLocationLatitude")
            }
        }
    }
    
    var currentLocationLongitude: Double? {
        get {
            let value = userDefaults.object(forKey: "currentLocationLongitude") as? Double
            return value
        }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: "currentLocationLongitude")
            } else {
                userDefaults.removeObject(forKey: "currentLocationLongitude")
            }
        }
    }
    
    var currentLocationTimezone: String? {
        get {
            return userDefaults.string(forKey: "currentLocationTimezone")
        }
        set {
            userDefaults.set(newValue, forKey: "currentLocationTimezone")
        }
    }
    
    var currentLocationTimestamp: Date? {
        get {
            return userDefaults.object(forKey: "currentLocationTimestamp") as? Date
        }
        set {
            userDefaults.set(newValue, forKey: "currentLocationTimestamp")
        }
    }
    
    // MARK: - Last Selected City Data
    
    var lastSelectedCityName: String? {
        get {
            return userDefaults.string(forKey: "lastSelectedCityName")
        }
        set {
            userDefaults.set(newValue, forKey: "lastSelectedCityName")
        }
    }
    
    var lastSelectedCityLatitude: Double? {
        get {
            let value = userDefaults.object(forKey: "lastSelectedCityLatitude") as? Double
            return value
        }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: "lastSelectedCityLatitude")
            } else {
                userDefaults.removeObject(forKey: "lastSelectedCityLatitude")
            }
        }
    }
    
    var lastSelectedCityLongitude: Double? {
        get {
            let value = userDefaults.object(forKey: "lastSelectedCityLongitude") as? Double
            return value
        }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: "lastSelectedCityLongitude")
            } else {
                userDefaults.removeObject(forKey: "lastSelectedCityLongitude")
            }
        }
    }
    
    var lastSelectedCityTimezoneId: String? {
        get {
            return userDefaults.string(forKey: "lastSelectedCityTimezoneId")
        }
        set {
            userDefaults.set(newValue, forKey: "lastSelectedCityTimezoneId")
        }
    }
    
    // MARK: - Widget Location Resolution
    
    /// Gets the appropriate location data for widgets based on current settings
    /// Returns tuple with (latitude, longitude, city, timezone) or nil if no valid location available
    func getWidgetLocation() -> (latitude: Double, longitude: Double, city: String, timezone: String)? {
        
        print("🔸 SharedDataManager: Getting widget location...")
        print("🔸 SharedDataManager: useCurrentLocation = \(useCurrentLocation)")
        
        if useCurrentLocation {
            // Check if current location data is available and fresh
            if let lat = currentLocationLatitude,
               let lon = currentLocationLongitude,
               let city = currentLocationCity,
               let timezone = currentLocationTimezone,
               let timestamp = currentLocationTimestamp {
                
                // Check if data is fresh (within 2 hours for better widget experience)
                let twoHoursAgo = Date().addingTimeInterval(-7200)
                if timestamp > twoHoursAgo {
                    print("🔸 SharedDataManager: Using current location data for widgets: \(city)")
                    return (latitude: lat, longitude: lon, city: city, timezone: timezone)
                } else {
                    print("🔸 SharedDataManager: Current location data is stale (older than 2 hours)")
                }
            } else {
                print("🔸 SharedDataManager: Current location data incomplete")
                print("  - lat: \(currentLocationLatitude?.description ?? "nil")")
                print("  - lon: \(currentLocationLongitude?.description ?? "nil")")
                print("  - city: \(currentLocationCity ?? "nil")")
                print("  - timezone: \(currentLocationTimezone ?? "nil")")
                print("  - timestamp: \(currentLocationTimestamp?.description ?? "nil")")
            }
        }
        
        // Fall back to last selected city
        if let lat = lastSelectedCityLatitude,
           let lon = lastSelectedCityLongitude,
           let city = lastSelectedCityName {
            
            // Use timezone or fall back to a reasonable default
            let timezone = lastSelectedCityTimezoneId ?? TimeZone.current.identifier
            print("🔸 SharedDataManager: Using last selected city data for widgets: \(city)")
            return (latitude: lat, longitude: lon, city: city, timezone: timezone)
        }
        
        print("🔸 SharedDataManager: No valid location data available for widgets")
        print("  - lastSelectedCityName: \(lastSelectedCityName ?? "nil")")
        print("  - lastSelectedCityLatitude: \(lastSelectedCityLatitude?.description ?? "nil")")
        print("  - lastSelectedCityLongitude: \(lastSelectedCityLongitude?.description ?? "nil")")
        
        // Last resort: provide a default location (San Francisco)
        print("🔸 SharedDataManager: Using default location (San Francisco)")
        return (latitude: 37.7749, longitude: -122.4194, city: "San Francisco", timezone: "America/Los_Angeles")
    }
    
    // MARK: - Widget Refresh Management
    
    /// Records when the data was last updated to help widgets determine if they need to refresh
    func markDataUpdated() {
        userDefaults.set(Date(), forKey: "lastDataUpdate")
        print("🔄 SharedDataManager: Marked data as updated at \(Date())")
    }
    
    /// Gets the timestamp of the last data update
    func getLastDataUpdate() -> Date? {
        return userDefaults.object(forKey: "lastDataUpdate") as? Date
    }
    
    /// Checks if data is fresh enough for widgets (within last 30 minutes)
    func isDataFresh() -> Bool {
        guard let lastUpdate = getLastDataUpdate() else { return false }
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800) // 30 minutes
        return lastUpdate > thirtyMinutesAgo
    }
    
    // MARK: - Debug Information
    
    func printDebugInfo() {
        print("📊 SharedDataManager Debug Info:")
        print("  - useCurrentLocation: \(useCurrentLocation)")
        print("  - currentLocationCity: \(currentLocationCity ?? "nil")")
        print("  - currentLocationLatitude: \(currentLocationLatitude?.description ?? "nil")")
        print("  - currentLocationLongitude: \(currentLocationLongitude?.description ?? "nil")")
        print("  - currentLocationTimezone: \(currentLocationTimezone ?? "nil")")
        print("  - currentLocationTimestamp: \(currentLocationTimestamp?.description ?? "nil")")
        print("  - lastSelectedCityName: \(lastSelectedCityName ?? "nil")")
        print("  - lastSelectedCityLatitude: \(lastSelectedCityLatitude?.description ?? "nil")")
        print("  - lastSelectedCityLongitude: \(lastSelectedCityLongitude?.description ?? "nil")")
        print("  - lastSelectedCityTimezoneId: \(lastSelectedCityTimezoneId ?? "nil")")
    }
}