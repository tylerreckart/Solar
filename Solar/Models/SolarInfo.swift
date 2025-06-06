// Solar/Models/SolarInfo.swift

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

    var heading: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((currentAzimuth / 22.5) + 0.5) % 16
        return directions[index]
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
    
    var timeFromSolarNoon: String? {
        let now = Date()
        guard now >= solarNoon else { return nil }
        return formatTimeDifference(from: solarNoon, to: now, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A", isDuration: true)
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
        
        if !isDuration && hour < 0 || (!isDuration && hour == 0 && minute < 0) {
            return defaultString
        }
        
        if hour == 0 && minute == 0 && !isDuration { return "Now" }
        
        var result = futurePrefix
        if hour > 0 { result += "\(hour)h " }
        if minute > 0 || (hour == 0 && minute == 0 && isDuration) { // Show 0m ago if duration and exactly on the mark
            result += "\(minute)m"
        } else if minute > 0 { // For "to" events, if hour is 0, show minutes
            result += "\(minute)m"
        }
        
        
        if isDuration { result += " " + pastSuffix }
        
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedResult.isEmpty {
            return isDuration ? "Just now" : "Now"
        }
        // Ensure "0m" is not shown alone for "to" events if it's exactly on the hour.
        if !isDuration && hour > 0 && minute == 0 {
            return "\(hour)h"
        }
        
        return trimmedResult
    }

    var daylightDuration: String {
        guard sunrise < sunset else { return "N/A" } // Ensure sunrise is before sunset
        let components = Calendar.current.dateComponents([.hour, .minute], from: sunrise, to: sunset)
        return "\(components.hour ?? 0)h \(components.minute ?? 0)m"
    }

    var sunProgress: Double {
        let now = Date()
        // If using placeholder dates, show sun at noon for a neutral position.
        if sunrise == SolarInfo.placeholderDate() || sunset == SolarInfo.placeholderDate() {
            return 0.5 // Noon position
        }

        guard Calendar.current.isDate(now, inSameDayAs: sunrise) else {
            if now < sunrise { return 0.0 }
            if now > sunset { return 1.0 }
            return 0.0
        }

        let totalDaylightSeconds = sunset.timeIntervalSince(sunrise)
        if totalDaylightSeconds <= 0 { return now > sunset ? 1.0 : 0.0 }
        
        let secondsSinceSunrise = now.timeIntervalSince(sunrise)
        let progress = secondsSinceSunrise / totalDaylightSeconds
        return max(0.0, min(1.0, progress))
    }
    
    // Helper to get a consistent placeholder date
    private static func placeholderDate() -> Date {
        var components = DateComponents()
        components.year = 2000 // A fixed old date to clearly identify it as placeholder
        components.month = 1
        components.day = 1
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date()
    }

    static func placeholder(city: String = "Loading...", lat: Double? = nil, lon: Double? = nil) -> SolarInfo {
        let phDate = placeholderDate()
        
        // Create a few placeholder UV data points for skeleton UI
        let placeholderHourlyUV = (0..<5).map { i in
            HourlyUV(time: Calendar.current.date(byAdding: .hour, value: i, to: Date()) ?? Date(), uvIndex: 0)
        }

        return SolarInfo(
            city: city,
            latitude: lat, // Could be nil initially
            longitude: lon, // Could be nil initially
            currentDate: Date(), // Current actual date for "Today" context
            sunrise: phDate,
            sunset: phDate,
            solarNoon: phDate,
            timezoneIdentifier: TimeZone.current.identifier, // Default to current, API will override
            hourlyUVData: placeholderHourlyUV, // Provide some skeleton data
            currentAltitude: 0.0,
            currentAzimuth: 90.0, // East, neutral placeholder
            uvIndex: 0,
            uvIndexCategory: "Low",
            civilTwilightBegin: phDate,
            civilTwilightEnd: phDate,
            nauticalTwilightBegin: phDate,
            nauticalTwilightEnd: phDate,
            astronomicalTwilightBegin: phDate,
            astronomicalTwilightEnd: phDate,
            usAQI: nil, // Keep as nil for "N/A" display
            pm2_5: nil,
            ozone: nil,
            moonrise: phDate,
            moonset: phDate,
            moonIlluminationFraction: 0.5, // Neutral placeholder
            weatherCode: nil, // No placeholder weather code
            cloudCover: nil // No placeholder cloud cover
        )
    }
}
