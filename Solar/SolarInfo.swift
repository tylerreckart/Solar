//
//  SolarInfo.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import Foundation

struct SolarInfo {
    var city: String
    var latitude: Double?
    var longitude: Double?
    var currentDate: Date // Represents the date for which the solar data (sunrise/sunset) is valid
    var sunrise: Date
    var sunset: Date
    var solarNoon: Date
    
    var currentAltitude: Double // Placeholder
    var currentAzimuth: Double  // Placeholder
    var uvIndex: Int
    var uvIndexCategory: String
    
    var daylightDuration: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: sunrise, to: sunset)
        return "\(components.hour ?? 0)h \(components.minute ?? 0)m"
    }
    
    var timeToSolarNoon: String {
        let now = Date()
        if now > solarNoon { return "Past Solar Noon" }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: solarNoon)
        return "\(components.hour ?? 0)h \(components.minute ?? 0)m remaining"
    }

    var sunProgress: Double {
        let now = Date()
        let totalDaylightSeconds = sunset.timeIntervalSince(sunrise)
        let secondsSinceSunrise = now.timeIntervalSince(sunrise)
        if totalDaylightSeconds <= 0 { return 0.0 }
        let progress = secondsSinceSunrise / totalDaylightSeconds
        return max(0.0, min(1.0, progress))
    }

    // Default placeholder initializer
    static func placeholder(city: String = "Philadelphia", lat: Double? = 39.9526, lon: Double? = -75.1652) -> SolarInfo {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025; components.month = 5; components.day = 13 // Fixed date for placeholder
        
        let placeholderDate = calendar.date(from: components)!
        
        components.hour = 5; components.minute = 45
        let sunriseDate = calendar.date(from: components)!
        
        components.hour = 20; components.minute = 05
        let sunsetDate = calendar.date(from: components)!
        
        components.hour = 12; components.minute = 55
        let solarNoonDate = calendar.date(from: components)!

        return SolarInfo(
            city: city,
            latitude: lat,
            longitude: lon,
            currentDate: placeholderDate,
            sunrise: sunriseDate,
            sunset: sunsetDate,
            solarNoon: solarNoonDate,
            currentAltitude: 45.0, // Placeholder
            currentAzimuth: 120.0, // Placeholder
            uvIndex: 4,
            uvIndexCategory: "Moderate"
        )
    }
}
