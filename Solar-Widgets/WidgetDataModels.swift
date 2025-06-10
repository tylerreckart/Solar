//
//  WidgetDataModels.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import Foundation
import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - Widget-specific Enums and Types

enum SkyCondition {
    case night
    case sunrise
    case daylight
    case sunset
}

struct SunPosition {
    let altitude: Double
    let azimuth: Double
}

public struct SolarPathData {
    /// Current sun position
    let currentPosition: SunPosition
    /// Sun position at sunrise
    let sunrisePosition: SunPosition
    /// Sun position at solar noon (maximum altitude for the day)
    let solarNoonPosition: SunPosition
    /// Sun position at sunset
    let sunsetPosition: SunPosition
    /// Progress along the sun's path (0.0 at sunrise, 1.0 at sunset)
    let sunProgress: Double
    /// Normalized altitude progress (0.0 at horizon, 1.0 at maximum daily altitude)
    let altitudeProgress: Double
    /// Maximum solar altitude for this day at this location
    let maxDailyAltitude: Double
    /// True solar noon time (may differ from 12:00 due to equation of time)
    let trueSolarNoon: Date
}

// MARK: - SunPositionCalculator
public struct SunPositionCalculator {

    // MARK: - Public Calculation Method
    
    /// Calculates comprehensive solar path data for accurate visualization
    /// - Parameters:
    ///   - date: The specific `Date` for which to calculate the sun's path data
    ///   - latitude: Observer's latitude in degrees
    ///   - longitude: Observer's longitude in degrees (East positive, West negative)
    ///   - timezoneIdentifier: The IANA timezone identifier for the given latitude/longitude
    ///   - sunrise: Sunrise time for the day
    ///   - sunset: Sunset time for the day
    ///   - solarNoon: Solar noon time for the day
    /// - Returns: A `SolarPathData` struct containing all data needed for accurate sun path visualization
    public static func calculateSolarPathData(
        date: Date,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        timezoneIdentifier: String,
        sunrise: Date,
        sunset: Date,
        solarNoon: Date
    ) -> SolarPathData? {
        guard let currentPosition = calculateSunPosition(date: date, latitude: latitude, longitude: longitude, timezoneIdentifier: timezoneIdentifier),
              let sunrisePosition = calculateSunPosition(date: sunrise, latitude: latitude, longitude: longitude, timezoneIdentifier: timezoneIdentifier),
              let solarNoonPosition = calculateSunPosition(date: solarNoon, latitude: latitude, longitude: longitude, timezoneIdentifier: timezoneIdentifier),
              let sunsetPosition = calculateSunPosition(date: sunset, latitude: latitude, longitude: longitude, timezoneIdentifier: timezoneIdentifier) else {
            return nil
        }
        
        // Calculate progress along the sun's path
        let totalDaylightSeconds = sunset.timeIntervalSince(sunrise)
        let secondsSinceSunrise = date.timeIntervalSince(sunrise)
        let sunProgress = totalDaylightSeconds > 0 ? max(0.0, min(1.0, secondsSinceSunrise / totalDaylightSeconds)) : 0.5
        
        // Calculate altitude progress (normalized to maximum daily altitude)
        let maxDailyAltitude = solarNoonPosition.altitude
        let altitudeProgress = maxDailyAltitude > 0 ? max(0.0, min(1.0, currentPosition.altitude / maxDailyAltitude)) : 0.0
        
        return SolarPathData(
            currentPosition: currentPosition,
            sunrisePosition: sunrisePosition,
            solarNoonPosition: solarNoonPosition,
            sunsetPosition: sunsetPosition,
            sunProgress: sunProgress,
            altitudeProgress: altitudeProgress,
            maxDailyAltitude: maxDailyAltitude,
            trueSolarNoon: solarNoon
        )
    }
    
    /// Calculates accurate sun position on visual path based on real altitude
    /// - Parameters:
    ///   - solarPathData: The calculated solar path data
    ///   - rect: The rect of the visualization area
    ///   - xInsetFactor: Horizontal inset factor for start/end points
    ///   - yBaseFactor: Vertical position factor for horizon line
    /// - Returns: CGPoint representing the sun's position on the visual path
    public static func calculateAccurateSunPosition(
        solarPathData: SolarPathData,
        in rect: CGRect,
        xInsetFactor: CGFloat = 0.1,
        yBaseFactor: CGFloat = 0.85
    ) -> CGPoint {
        let width = rect.width
        let height = rect.height
        
        // Horizontal position based on time progress (sunrise to sunset)
        let x = width * xInsetFactor + (width * (1.0 - 2.0 * xInsetFactor)) * CGFloat(solarPathData.sunProgress)
        
        // Vertical position based on actual sun altitude
        // Transform altitude to visual height using realistic scaling
        let maxAltitudeRadians = solarPathData.maxDailyAltitude * .pi / 180.0
        let currentAltitudeRadians = max(0, solarPathData.currentPosition.altitude) * .pi / 180.0
        
        // Use sine function to convert altitude to visual height (more accurate than linear)
        // This accounts for the fact that altitude changes are more dramatic near horizon
        let normalizedHeight = sin(currentAltitudeRadians) / sin(maxAltitudeRadians)
        
        // Scale the height to available visual space
        let availableHeight = height * (yBaseFactor - 0.1) // Leave 10% margin at top
        let y = height * yBaseFactor - availableHeight * CGFloat(normalizedHeight)
        
        return CGPoint(x: x, y: max(height * 0.1, y)) // Ensure sun doesn't go above 10% from top
    }
    
    /// Generates the accurate sun path curve for the entire day
    /// - Parameters:
    ///   - date: Date for which to calculate the path
    ///   - latitude: Observer's latitude
    ///   - longitude: Observer's longitude
    ///   - timezoneIdentifier: Timezone identifier
    ///   - sunrise: Sunrise time
    ///   - sunset: Sunset time
    ///   - solarNoon: Solar noon time
    ///   - rect: Visualization rect
    ///   - xInsetFactor: Horizontal inset factor
    ///   - yBaseFactor: Vertical baseline factor
    ///   - pointCount: Number of points to calculate for smooth curve
    /// - Returns: Array of CGPoints representing the accurate sun path
    public static func generateAccurateSunPath(
        date: Date,
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        timezoneIdentifier: String,
        sunrise: Date,
        sunset: Date,
        solarNoon: Date,
        in rect: CGRect,
        xInsetFactor: CGFloat = 0.1,
        yBaseFactor: CGFloat = 0.85,
        pointCount: Int = 50
    ) -> [CGPoint] {
        var pathPoints: [CGPoint] = []
        let totalDaylightSeconds = sunset.timeIntervalSince(sunrise)
        
        guard totalDaylightSeconds > 0 else { return pathPoints }
        
        // Calculate points along the sun's path throughout the day
        for i in 0...pointCount {
            let progress = Double(i) / Double(pointCount)
            let timeOffset = totalDaylightSeconds * progress
            let calculationTime = sunrise.addingTimeInterval(timeOffset)
            
            if let pathData = calculateSolarPathData(
                date: calculationTime,
                latitude: latitude,
                longitude: longitude,
                timezoneIdentifier: timezoneIdentifier,
                sunrise: sunrise,
                sunset: sunset,
                solarNoon: solarNoon
            ) {
                let point = calculateAccurateSunPosition(
                    solarPathData: pathData,
                    in: rect,
                    xInsetFactor: xInsetFactor,
                    yBaseFactor: yBaseFactor
                )
                pathPoints.append(point)
            }
        }
        
        return pathPoints
    }

    /// Calculates the sun's altitude and azimuth for a given date, time, and location.
    /// - Parameters:
    ///   - date: The specific `Date` for which to calculate the sun's position.
    ///   - latitude: Observer's latitude in degrees.
    ///   - longitude: Observer's longitude in degrees (East positive, West negative).
    ///   - timezoneIdentifier: The IANA timezone identifier for the given latitude/longitude (e.g., "America/New_York").
    ///                         This is crucial for accurately determining local solar time.
    /// - Returns: A `SunPosition` struct containing altitude and azimuth in degrees, or `nil` if timezone information is invalid.
    static func calculateSunPosition(date: Date, latitude: CLLocationDegrees, longitude: CLLocationDegrees, timezoneIdentifier: String) -> SunPosition? {
        guard let timeZone = TimeZone(identifier: timezoneIdentifier) else {
            print("❌ SunPositionCalculator: Invalid timezoneIdentifier: \(timezoneIdentifier)")
            return nil
        }

        // 1. Julian Day
        let julianDay = calculateJulianDay(date: date, timezone: timeZone)
        let julianCentury = (julianDay - 2451545.0) / 36525.0

        // 2. Solar Coordinates
        let meanLongitudeRad = normalizeAngle(degreesToRadians(280.46646 + julianCentury * (36000.76983 + julianCentury * 0.0003032)))
        let meanAnomalyRad = normalizeAngle(degreesToRadians(357.52911 + julianCentury * (35999.05029 - julianCentury * 0.0001537)))

        let eccentEarthOrbit = 0.016708634 - julianCentury * (0.000042037 + julianCentury * 0.0000001267)

        let equationOfCenterRad = sin(meanAnomalyRad) * (1.914602 - julianCentury * (0.004817 + 0.000014 * julianCentury)) +
                                  sin(2 * meanAnomalyRad) * (0.019993 - julianCentury * 0.000101) +
                                  sin(3 * meanAnomalyRad) * 0.000289
        
        let trueLongitudeRad = meanLongitudeRad + degreesToRadians(equationOfCenterRad)
        // let trueAnomalyRad = meanAnomalyRad + equationOfCenterRad // Not directly needed for declination/RA with this formula set

        let obliquityCorrectionRad = degreesToRadians(23.0 + (26.0 / 60.0) + (21.448 / 3600.0) - julianCentury * (46.8150 / 3600.0 + julianCentury * (0.00059 / 3600.0 - julianCentury * (0.001813 / 3600.0))))
        
        // Sun's Right Ascension (alpha) and Declination (delta)
        var rightAscensionRad = atan2(cos(obliquityCorrectionRad) * sin(trueLongitudeRad), cos(trueLongitudeRad))
        if rightAscensionRad < 0 {
            rightAscensionRad += 2 * .pi
        }
        let declinationRad = asin(sin(obliquityCorrectionRad) * sin(trueLongitudeRad))

        // 3. Hour Angle
        let greenwichMeanSiderealTimeHours = 6.697374558 + 0.06570982441908 * (julianDay - 2451545.0) + 1.00273790935 * getUTCHours(from: date)
        let localMeanSiderealTimeHours = (greenwichMeanSiderealTimeHours + longitude / 15.0).truncatingRemainder(dividingBy: 24.0)
        
        let hourAngleRad = degreesToRadians(localMeanSiderealTimeHours * 15.0) - rightAscensionRad

        // 4. Altitude and Azimuth
        let latRad = degreesToRadians(latitude)
        
        var altitudeRad = asin(sin(latRad) * sin(declinationRad) + cos(latRad) * cos(declinationRad) * cos(hourAngleRad))
        
        var azimuthRad = atan2(sin(hourAngleRad), cos(hourAngleRad) * sin(latRad) - tan(declinationRad) * cos(latRad))
        azimuthRad += .pi // Azimuth from South, convert to North-based clockwise
        if azimuthRad < 0 { azimuthRad += 2 * .pi }
        if azimuthRad >= 2 * .pi { azimuthRad -= 2 * .pi }


        // 5. Atmospheric Refraction (for altitude)
        // Simplified model, good for altitudes > ~5 degrees. More complex models exist for lower altitudes.
        let atmosphericRefractionDegrees: Double
        let altitudeDeg = radiansToDegrees(altitudeRad)

        if altitudeDeg > 85.0 {
            atmosphericRefractionDegrees = 0.0
        } else {
            let h = altitudeDeg // altitude in degrees
            if h > 5.0 {
                atmosphericRefractionDegrees = (58.1 / tan(degreesToRadians(h)) - 0.07 / pow(tan(degreesToRadians(h)), 3) + 0.000086 / pow(tan(degreesToRadians(h)), 5)) / 3600.0
            } else if h > -0.575 { // Approximation for lower altitudes
                atmosphericRefractionDegrees = (1735.0 + h * (-518.2 + h * (103.4 + h * (-12.79 + h * 0.711)))) / 3600.0
            } else {
                atmosphericRefractionDegrees = -20.774 / tan(degreesToRadians(h)) / 3600.0 // Simplified
            }
        }
        altitudeRad += degreesToRadians(atmosphericRefractionDegrees)
        
        // Ensure altitude is within -90 to +90
        let finalAltitudeDeg = max(-90.0, min(90.0, radiansToDegrees(altitudeRad)))
        let finalAzimuthDeg = radiansToDegrees(azimuthRad)

        return SunPosition(altitude: finalAltitudeDeg, azimuth: finalAzimuthDeg)
    }

    // MARK: - Private Helper Methods

    private static func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }

    private static func normalizeAngle(_ angleRad: Double) -> Double {
        var result = angleRad.truncatingRemainder(dividingBy: 2.0 * .pi)
        if result < 0 {
            result += 2.0 * .pi
        }
        return result
    }
    
    private static func getUTCHours(from date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // UTC
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let nanosecond = Double(components.nanosecond ?? 0)
        return hour + (minute / 60.0) + (second / 3600.0) + (nanosecond / 3_600_000_000_000.0)
    }

    private static func calculateJulianDay(date: Date, timezone: TimeZone) -> Double {
        // Use current calendar configured for the specified timezone to get local day, month, year
        var calendar = Calendar.current
        calendar.timeZone = timezone
        
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Get time components in UTC for fractional part of Julian Day
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let hour = utcCalendar.component(.hour, from: date)
        let minute = utcCalendar.component(.minute, from: date)
        let second = utcCalendar.component(.second, from: date)
        let nanosecond = utcCalendar.component(.nanosecond, from: date)

        let dayFraction = (Double(hour) + Double(minute)/60.0 + Double(second)/3600.0 + Double(nanosecond)/3_600_000_000_000.0) / 24.0

        var localYear = year
        var localMonth = month
        if month <= 2 {
            localYear -= 1
            localMonth += 12
        }
        
        let a = floor(Double(localYear) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        
        let jd = floor(365.25 * (Double(localYear) + 4716.0)) + floor(30.6001 * (Double(localMonth) + 1.0)) + Double(day) + b - 1524.5 + dayFraction
        return jd
    }
}


// MARK: - Shared Widget Data Models

struct SolarWidgetEntry: TimelineEntry {
    let date: Date
    let city: String
    let latitude: Double?
    let longitude: Double?
    let sunrise: Date
    let sunset: Date
    let solarNoon: Date
    let sunPosition: SunPosition?
    let skyCondition: SkyCondition
    let nextEvent: SolarEvent
    let sunProgress: Double
    let isLocationAuthorized: Bool
    let timezoneIdentifier: String?
    
    /// Enhanced solar path data with accurate astronomical calculations
    var solarPathData: SolarPathData? {
        guard let lat = latitude,
              let lon = longitude,
              let timezone = timezoneIdentifier else {
            return nil
        }
        
        return SunPositionCalculator.calculateSolarPathData(
            date: date,
            latitude: lat,
            longitude: lon,
            timezoneIdentifier: timezone,
            sunrise: sunrise,
            sunset: sunset,
            solarNoon: solarNoon
        )
    }
    
    static func placeholder() -> SolarWidgetEntry {
        let now = Date()
        let sunrise = Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now
        let sunset = Calendar.current.date(byAdding: .hour, value: 4, to: now) ?? now
        let solarNoon = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        
        return SolarWidgetEntry(
            date: now,
            city: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            sunrise: sunrise,
            sunset: sunset,
            solarNoon: solarNoon,
            sunPosition: SunPosition(altitude: 45.0, azimuth: 180.0),
            skyCondition: .daylight,
            nextEvent: .sunset(sunset),
            sunProgress: 0.6,
            isLocationAuthorized: true,
            timezoneIdentifier: TimeZone.current.identifier
        )
    }
}

struct AirQualityWidgetEntry: TimelineEntry {
    let date: Date
    let location: String
    let aqi: Int?
    let aqiCategory: String
    let pm25: Double?
    let recommendation: String
    let healthAlert: String?
    let isDataStale: Bool
    let isLocationAuthorized: Bool
    
    func aqiGradientColors() -> [Color] {
        guard let aqi = aqi else { return [.gray, .gray.opacity(0.7)] }
        
        if aqi <= 50 {
            return [.green, .mint]
        } else if aqi <= 100 {
            return [.yellow, .orange.opacity(0.7)]
        } else if aqi <= 150 {
            return [.orange, .red.opacity(0.7)]
        } else if aqi <= 200 {
            return [.red, .pink]
        } else if aqi <= 300 {
            return [.purple, .indigo]
        } else {
            return [.brown, .red]
        }
    }
    
    static func placeholder() -> AirQualityWidgetEntry {
        return AirQualityWidgetEntry(
            date: Date(),
            location: "San Francisco",
            aqi: 42,
            aqiCategory: "Good",
            pm25: 8.5,
            recommendation: "Great for outdoor activities",
            healthAlert: nil,
            isDataStale: false,
            isLocationAuthorized: true
        )
    }
}

struct UVWidgetEntry: TimelineEntry {
    let date: Date
    let location: String
    let currentUV: Int
    let uvCategory: String
    let hourlyForecast: [WidgetHourlyUV]
    let peakUVTime: Date?
    let peakUVValue: Int
    let protectionAdvice: String
    let isLocationAuthorized: Bool
    
    func uvGradientColors() -> [Color] {
        let uv = currentUV
        
        if uv <= 2 {
            return [.green, .mint]
        } else if uv <= 5 {
            return [.yellow, .orange.opacity(0.7)]
        } else if uv <= 7 {
            return [.orange, .red.opacity(0.7)]
        } else if uv <= 10 {
            return [.red, .pink]
        } else {
            return [.purple, .indigo]
        }
    }
    
    static func placeholder() -> UVWidgetEntry {
        let now = Date()
        let hourlyData = (0..<8).map { i in
            WidgetHourlyUV(
                time: Calendar.current.date(byAdding: .hour, value: i, to: now) ?? now,
                uvIndex: Double([2, 4, 6, 8, 7, 5, 3, 1][i])
            )
        }
        
        return UVWidgetEntry(
            date: now,
            location: "San Francisco",
            currentUV: 6,
            uvCategory: "High",
            hourlyForecast: hourlyData,
            peakUVTime: Calendar.current.date(byAdding: .hour, value: 3, to: now),
            peakUVValue: 8,
            protectionAdvice: "Wear sunscreen and seek shade",
            isLocationAuthorized: true
        )
    }
}

// MARK: - Supporting Types

enum SolarEvent {
    case sunrise(Date)
    case solarNoon(Date)
    case sunset(Date)
    
    var date: Date {
        switch self {
        case .sunrise(let date), .solarNoon(let date), .sunset(let date):
            return date
        }
    }
    
    var title: String {
        switch self {
        case .sunrise: return "Sunrise"
        case .solarNoon: return "Solar Noon"
        case .sunset: return "Sunset"
        }
    }
    
    var icon: String {
        switch self {
        case .sunrise: return "sunrise.fill"
        case .solarNoon: return "sun.max.fill"
        case .sunset: return "sunset.fill"
        }
    }
}

struct WidgetHourlyUV: Identifiable {
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

// MARK: - Widget Color Extensions

extension Color {
    static func uvColor(for category: String) -> Color {
        switch category.lowercased() {
        case "low": return Color.green
        case "moderate": return Color.yellow
        case "high": return Color.orange
        case "very high": return Color.red
        case "extreme": return Color.purple
        default: return Color.gray
        }
    }
    
    static func aqiColor(for aqi: Int?) -> Color {
        guard let aqi = aqi else { return Color.gray }
        if aqi <= 50 { return Color.green }
        if aqi <= 100 { return Color.yellow }
        if aqi <= 150 { return Color.orange }
        if aqi <= 200 { return Color.red }
        if aqi <= 300 { return Color.purple }
        return Color.pink
    }
    
}

// MARK: - Widget Formatting Extensions

extension Date {
    func timeString(in timeZone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if let tz = timeZone {
            formatter.timeZone = tz
        }
        return formatter.string(from: self)
    }
    
    func timeUntil() -> String {
        let interval = self.timeIntervalSince(Date())
        if interval <= 0 { return "Now" }
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
