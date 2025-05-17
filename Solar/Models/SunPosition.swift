//
//  SunPosition.swift
//  Solar
//
//  Created by Tyler Reckart on 5/17/25.
//

import Foundation
import CoreLocation // For CLLocationDegrees

// MARK: - SunPosition Struct
public struct SunPosition {
    /// The altitude of the sun above the horizon, in degrees.
    /// Corrected for atmospheric refraction.
    public let altitude: CLLocationDegrees
    /// The azimuth of the sun, in degrees, measured clockwise from true North (North=0°, East=90°, South=180°, West=270°).
    public let azimuth: CLLocationDegrees
}

// MARK: - SunPositionCalculator
public struct SunPositionCalculator {

    // MARK: - Public Calculation Method
    
    /// Calculates the sun's altitude and azimuth for a given date, time, and location.
    /// - Parameters:
    ///   - date: The specific `Date` for which to calculate the sun's position.
    ///   - latitude: Observer's latitude in degrees.
    ///   - longitude: Observer's longitude in degrees (East positive, West negative).
    ///   - timezoneIdentifier: The IANA timezone identifier for the given latitude/longitude (e.g., "America/New_York").
    ///                         This is crucial for accurately determining local solar time.
    /// - Returns: A `SunPosition` struct containing altitude and azimuth in degrees, or `nil` if timezone information is invalid.
    public static func calculateSunPosition(date: Date, latitude: CLLocationDegrees, longitude: CLLocationDegrees, timezoneIdentifier: String) -> SunPosition? {
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
