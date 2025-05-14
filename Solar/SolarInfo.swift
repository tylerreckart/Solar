//
//  SolarInfo.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import Foundation

import Foundation

struct SolarInfo: Equatable {
    var city: String
    var latitude: Double?
    var longitude: Double?
    var currentDate: Date
    var sunrise: Date
    var sunset: Date
    var solarNoon: Date
    var timezoneIdentifier: String?
    var hourlyUVData: [HourlyUV]

    var currentAltitude: Double // Placeholder, consider fetching this if API supports
    var currentAzimuth: Double  // Placeholder, consider fetching this if API supports
    var uvIndex: Int
    var uvIndexCategory: String

    // For future weather integration for more accurate sky gradient
    var weatherCode: Int? // WMO Weather interpretation codes
    var cloudCover: Int?  // Percentage
    
    struct HourlyUV: Identifiable, Hashable {
        let id = UUID()
        let time: Date
        let uvIndex: Double

        var uvCategory: String {
            let roundedUV = Int(round(uvIndex))
            if roundedUV >= 11 { return "Extreme" }
            else if roundedUV >= 8 { return "Very High" }
            else if roundedUV >= 6 { return "High" }
            else if roundedUV >= 3 { return "Moderate" }
            else { return "Low" }
        }
    }
    
    static func == (lhs: SolarInfo, rhs: SolarInfo) -> Bool {
        return lhs.city == rhs.city &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.currentDate == rhs.currentDate &&
        lhs.sunrise == rhs.sunrise &&
        lhs.sunset == rhs.sunset &&
        lhs.solarNoon == rhs.solarNoon &&
        lhs.timezoneIdentifier == rhs.timezoneIdentifier &&
        lhs.hourlyUVData == rhs.hourlyUVData
    }

    var daylightDuration: String {
        guard sunrise < sunset else { return "N/A" } // Ensure sunrise is before sunset
        let components = Calendar.current.dateComponents([.hour, .minute], from: sunrise, to: sunset)
        return "\(components.hour ?? 0)h \(components.minute ?? 0)m"
    }

    var timeToSolarNoon: String {
        let now = Date()
        guard now < solarNoon, sunrise < solarNoon else { return "Past Solar Noon" }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: solarNoon)
        if (components.hour ?? 0) < 0 || (components.minute ?? 0) < 0 { return "Past Solar Noon" }
        return "\(components.hour ?? 0)h \(components.minute ?? 0)m remaining"
    }

    var sunProgress: Double {
        let now = Date()
        // Ensure dates are for the same day for accurate progress
        guard Calendar.current.isDate(now, inSameDayAs: sunrise) else {
            if now < sunrise { return 0.0 } // Before sunrise on the current day
            if now > sunset { return 1.0 } // After sunset on the current day
            return 0.0 // Default if dates are mismatched significantly
        }

        let totalDaylightSeconds = sunset.timeIntervalSince(sunrise)
        if totalDaylightSeconds <= 0 { return now > sunset ? 1.0 : 0.0 } // Handles edge cases or invalid data
        
        let secondsSinceSunrise = now.timeIntervalSince(sunrise)
        let progress = secondsSinceSunrise / totalDaylightSeconds
        return max(0.0, min(1.0, progress))
    }

    static func placeholder(city: String = "Loading...", lat: Double? = nil, lon: Double? = nil) -> SolarInfo {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = Calendar.current.component(.year, from: Date())
        components.month = Calendar.current.component(.month, from: Date())
        components.day = Calendar.current.component(.day, from: Date())
        
        let placeholderDate = calendar.date(from: components) ?? Date()
        
        // Create somewhat realistic placeholders based on current time if possible
        let sunriseDate = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: placeholderDate) ?? Date()
        let sunsetDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: placeholderDate) ?? Date()
        let solarNoonDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: placeholderDate) ?? Date()

        return SolarInfo(
            city: city,
            latitude: lat,
            longitude: lon,
            currentDate: placeholderDate,
            sunrise: sunriseDate,
            sunset: sunsetDate,
            solarNoon: solarNoonDate,
            hourlyUVData: [],
            currentAltitude: 0.0,
            currentAzimuth: 0.0,
            uvIndex: 0,
            uvIndexCategory: "Low",
            weatherCode: nil,
            cloudCover: nil
        )
    }
}
