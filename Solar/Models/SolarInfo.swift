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
    
    var civilTwilightBegin: Date?
    var civilTwilightEnd: Date?
    var nauticalTwilightBegin: Date?
    var nauticalTwilightEnd: Date?
    var astronomicalTwilightBegin: Date?
    var astronomicalTwilightEnd: Date?
    
    var usAQI: Int?
    var usAQICategory: String {
        guard let aqi = usAQI else { return "N/A" }
        if aqi <= 50 { return "Good" }
        if aqi <= 100 { return "Moderate" }
        if aqi <= 150 { return "Unhealthy for Sensitive Groups" }
        if aqi <= 200 { return "Unhealthy" }
        if aqi <= 300 { return "Very Unhealthy" }
        return "Hazardous"
    }
    var pm2_5: Double?
    var ozone: Double?
    
    var moonrise: Date?
    var moonset: Date?
    var moonIlluminationFraction: Double?

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
    
    var moonPhaseName: String {
        guard let illumination = moonIlluminationFraction else { return "N/A" }
        if illumination < 0.03 { return "New Moon" }
        if illumination < 0.23 { return "Waxing Crescent" }
        if illumination < 0.27 { return "First Quarter" }
        if illumination < 0.48 { return "Waxing Gibbous" }
        if illumination < 0.52 { return "Full Moon" }
        if illumination < 0.73 { return "Waning Gibbous" }
        if illumination < 0.77 { return "Last Quarter" }
        if illumination < 0.97 { return "Waning Crescent" }
        if illumination <= 1.0 { return "Full Moon" }
        return "N/A"
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
        lhs.uvIndex == rhs.uvIndex &&
        lhs.uvIndexCategory == rhs.uvIndexCategory &&
        lhs.hourlyUVData == rhs.hourlyUVData &&
        lhs.civilTwilightBegin == rhs.civilTwilightBegin &&
        lhs.civilTwilightEnd == rhs.civilTwilightEnd &&
        lhs.nauticalTwilightBegin == rhs.nauticalTwilightBegin &&
        lhs.nauticalTwilightEnd == rhs.nauticalTwilightEnd &&
        lhs.astronomicalTwilightBegin == rhs.astronomicalTwilightBegin &&
        lhs.astronomicalTwilightEnd == rhs.astronomicalTwilightEnd &&
        lhs.moonrise == rhs.moonrise &&
        lhs.moonset == rhs.moonset &&
        lhs.moonIlluminationFraction == rhs.moonIlluminationFraction &&
        lhs.weatherCode == rhs.weatherCode &&
        lhs.cloudCover == rhs.cloudCover &&
        lhs.usAQI == rhs.usAQI &&
        lhs.pm2_5 == rhs.pm2_5 &&
        lhs.ozone == rhs.ozone
        
    }
    
    var timeToSunrise: String? {
        let now = Date()
        guard now < sunrise else { return nil } // Or "Past" or "Risen"
        return formatTimeDifference(from: now, to: sunrise, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A")
    }

    var timeFromSunrise: String? {
        let now = Date()
        guard now >= sunrise else { return nil }
        return formatTimeDifference(from: sunrise, to: now, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A", isDuration: true)
    }
    
    var timeToSolarNoon: String? {
        let now = Date()
        guard now < solarNoon else { return nil }
        return formatTimeDifference(from: now, to: solarNoon, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A")
    }

    var timeToSunset: String? {
        let now = Date()
        guard now < sunset else { return nil }
        return formatTimeDifference(from: now, to: sunset, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A")
    }
    
    var timeFromSunset: String? { // How long ago sunset was
        let now = Date()
        guard now >= sunset else { return nil }
        return formatTimeDifference(from: sunset, to: now, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A", isDuration: true)
    }
    
    public func formatTimeDifference(from: Date, to: Date, futurePrefix: String, pastSuffix: String, defaultString: String, isDuration: Bool = false) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: from, to: to)
        guard let hour = components.hour, let minute = components.minute else { return defaultString }

        if !isDuration && hour < 0 || (!isDuration && hour == 0 && minute < 0) { // Event is in the past
            return defaultString // Or specific "Past" message could be handled by caller
        }
        
        if hour == 0 && minute == 0 && !isDuration { return "Now" }

        var result = futurePrefix
        if hour > 0 { result += "\(hour)h " }
        if minute > 0 || hour == 0 { result += "\(minute)m" } // show 0m if only minutes left or it's exactly on the hour
        if !isDuration { result += "" } // " remaining" or similar can be added by caller
        else { result += " " + pastSuffix }


        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (isDuration ? "0m ago" : "Now") : result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var daylightDuration: String {
        guard sunrise < sunset else { return "N/A" } // Ensure sunrise is before sunset
        let components = Calendar.current.dateComponents([.hour, .minute], from: sunrise, to: sunset)
        return "\(components.hour ?? 0)h \(components.minute ?? 0)m"
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
                    city: city, latitude: lat, longitude: lon, currentDate: placeholderDate,
                    sunrise: sunriseDate, sunset: sunsetDate, solarNoon: solarNoonDate,
                    timezoneIdentifier: TimeZone.current.identifier, hourlyUVData: [], currentAltitude: 0.0, currentAzimuth: 0.0,
                    uvIndex: 0, uvIndexCategory: "Low",
                    civilTwilightBegin: nil, civilTwilightEnd: nil,
                    nauticalTwilightBegin: nil, nauticalTwilightEnd: nil,
                    astronomicalTwilightBegin: nil, astronomicalTwilightEnd: nil,
                    usAQI: nil, pm2_5: nil, ozone: nil,
                    moonrise: nil, moonset: nil, moonIlluminationFraction: nil,
                    weatherCode: nil, cloudCover: nil
                )
    }
}
