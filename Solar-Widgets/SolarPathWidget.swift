//
//  SolarPathWidget.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import WidgetKit
import SwiftUI

struct SolarPathWidget: Widget {
    let kind: String = "SolarPathWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SolarPathProvider()) { entry in
            SolarPathWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        gradient: Gradient(colors: Color.skyGradientColors(for: entry.skyCondition)),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Solar Path")
        .description("Track the sun's journey across the sky with sunrise and sunset times.")
        .supportedFamilies([.systemMedium])
    }
}

struct SolarPathProvider: TimelineProvider {
    private let sharedDataManager = SharedDataManager.shared
    private let apiService = WidgetSolarAPIService()
    
    func placeholder(in context: Context) -> SolarWidgetEntry {
        SolarWidgetEntry.placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (SolarWidgetEntry) -> ()) {
        Task {
            let entry = await fetchSolarWidgetEntry() ?? SolarWidgetEntry.placeholder()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SolarWidgetEntry>) -> ()) {
        print("🔄 SolarPathWidget: getTimeline called - fetching fresh data")
        Task {
            let entry = await fetchSolarWidgetEntry() ?? SolarWidgetEntry.placeholder()
            
            // Create multiple timeline entries for more dynamic updates
            var entries: [SolarWidgetEntry] = [entry]
            
            // Use the location's timezone for timeline calculations
            let locationTimezone = TimeZone(identifier: entry.timezoneIdentifier!) ?? TimeZone.current
            var calendar = Calendar.current
            calendar.timeZone = locationTimezone
            
            // Add entries for the next few hours to show sun progress
            for minutesAhead in [5, 15, 30, 60] {
                if let futureDate = calendar.date(byAdding: .minute, value: minutesAhead, to: Date()) {
                    // Recalculate sun progress for future time
                    let totalDaylight = entry.sunset.timeIntervalSince(entry.sunrise)
                    let elapsed = futureDate.timeIntervalSince(entry.sunrise)
                    let futureProgress = totalDaylight > 0 ? max(0.0, min(1.0, elapsed / totalDaylight)) : 0.5
                    
                    // Recalculate sky condition for future time
                    let futureSkyCondition = determineSkyCondition(
                        currentTime: futureDate,
                        sunrise: entry.sunrise,
                        sunset: entry.sunset,
                        timezone: locationTimezone
                    )
                    
                    // Recalculate next event for future time
                    let futureNextEvent = determineNextSolarEvent(
                        currentTime: futureDate,
                        sunrise: entry.sunrise,
                        solarNoon: entry.solarNoon,
                        sunset: entry.sunset,
                        timezone: locationTimezone
                    )
                    
                    // Create new entry with updated date and progress
                    let futureEntry = SolarWidgetEntry(
                        date: futureDate,
                        city: entry.city,
                        latitude: entry.latitude,
                        longitude: entry.longitude,
                        sunrise: entry.sunrise,
                        sunset: entry.sunset,
                        solarNoon: entry.solarNoon,
                        sunPosition: entry.sunPosition,
                        skyCondition: futureSkyCondition,
                        nextEvent: futureNextEvent,
                        sunProgress: futureProgress,
                        isLocationAuthorized: entry.isLocationAuthorized,
                        timezoneIdentifier: entry.timezoneIdentifier
                    )
                    
                    entries.append(futureEntry)
                }
            }
            
            // Next major refresh in 30 minutes with atEnd policy for more responsive updates
            let nextUpdate = calendar.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
    
    private func fetchSolarWidgetEntry() async -> SolarWidgetEntry? {
        // Get location data from shared storage (now always returns a value with fallback)
        let location = sharedDataManager.getWidgetLocation()!
        
        do {
            // Fetch solar data from API
            let solarData = try await apiService.fetchSolarData(
                latitude: location.latitude,
                longitude: location.longitude,
                timezone: location.timezone
            )
            
            // Convert API response to widget entry
            return createSolarWidgetEntry(
                from: solarData,
                location: location
            )
            
        } catch {
            print("🔸 SolarPathWidget: Error fetching solar data: \(error.localizedDescription)")
            return createErrorEntry(location: location, error: error)
        }
    }
    
    private func createSolarWidgetEntry(
        from solarData: WidgetSolarResponse,
        location: (latitude: Double, longitude: Double, city: String, timezone: String)
    ) -> SolarWidgetEntry {
        
        // Create timezone for the location
        let locationTimezone = TimeZone(identifier: location.timezone) ?? TimeZone.current
        
        // Get current time in location's timezone
        let now = Date()
        let sunrise = solarData.todaySunrise ?? now
        let sunset = solarData.todaySunset ?? now
        let solarNoon = solarData.solarNoon ?? now
        
        // Calculate sun position using the enhanced calculator with location timezone
        let sunPosition = SunPositionCalculator.calculateSunPosition(
            date: now,
            latitude: location.latitude,
            longitude: location.longitude,
            timezoneIdentifier: location.timezone
        )
        
        // Determine sky condition based on local time in target timezone
        let skyCondition = determineSkyCondition(
            currentTime: now,
            sunrise: sunrise,
            sunset: sunset,
            timezone: locationTimezone
        )
        
        // Calculate next solar event using local time
        let nextEvent = determineNextSolarEvent(
            currentTime: now,
            sunrise: sunrise,
            solarNoon: solarNoon,
            sunset: sunset,
            timezone: locationTimezone
        )
        
        // Calculate sun progress using actual solar times
        let sunProgress: Double
        if now < sunrise {
            sunProgress = 0.0
        } else if now > sunset {
            sunProgress = 1.0
        } else {
            let totalDaylight = sunset.timeIntervalSince(sunrise)
            let elapsed = now.timeIntervalSince(sunrise)
            sunProgress = totalDaylight > 0 ? elapsed / totalDaylight : 0.5
        }
        
        return SolarWidgetEntry(
            date: now,
            city: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
            sunrise: sunrise,
            sunset: sunset,
            solarNoon: solarNoon,
            sunPosition: sunPosition,
            skyCondition: skyCondition,
            nextEvent: nextEvent,
            sunProgress: sunProgress,
            isLocationAuthorized: true,
            timezoneIdentifier: location.timezone
        )
    }
    
    private func createLocationUnavailableEntry() -> SolarWidgetEntry {
        let now = Date()
        return SolarWidgetEntry(
            date: now,
            city: "Location Unavailable",
            latitude: nil,
            longitude: nil,
            sunrise: now,
            sunset: now,
            solarNoon: now,
            sunPosition: nil,
            skyCondition: .daylight,
            nextEvent: .sunrise(now),
            sunProgress: 0.5,
            isLocationAuthorized: false,
            timezoneIdentifier: TimeZone.current.identifier
        )
    }
    
    private func createErrorEntry(
        location: (latitude: Double, longitude: Double, city: String, timezone: String),
        error: Error
    ) -> SolarWidgetEntry {
        let now = Date()
        return SolarWidgetEntry(
            date: now,
            city: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
            sunrise: now,
            sunset: now,
            solarNoon: now,
            sunPosition: nil,
            skyCondition: .daylight,
            nextEvent: .sunrise(now),
            sunProgress: 0.5,
            isLocationAuthorized: true,
            timezoneIdentifier: location.timezone
        )
    }
    
    private func determineSkyCondition(
        currentTime: Date,
        sunrise: Date,
        sunset: Date,
        timezone: TimeZone
    ) -> SkyCondition {
        let civilTwilightDuration: TimeInterval = 30 * 60 // 30 minutes
        
        if currentTime < sunrise.addingTimeInterval(-civilTwilightDuration) ||
           currentTime > sunset.addingTimeInterval(civilTwilightDuration) {
            return .night
        } else if currentTime < sunrise.addingTimeInterval(civilTwilightDuration) {
            return .sunrise
        } else if currentTime > sunset.addingTimeInterval(-civilTwilightDuration) {
            return .sunset
        } else {
            return .daylight
        }
    }
    
    private func determineNextSolarEvent(
        currentTime: Date,
        sunrise: Date,
        solarNoon: Date,
        sunset: Date,
        timezone: TimeZone
    ) -> SolarEvent {
        if currentTime < sunrise {
            return .sunrise(sunrise)
        } else if currentTime < solarNoon {
            return .solarNoon(solarNoon)
        } else if currentTime < sunset {
            return .sunset(sunset)
        } else {
            // Next day's sunrise (calculated in the location's timezone)
            var calendar = Calendar.current
            calendar.timeZone = timezone
            let nextDaySunrise = calendar.date(byAdding: .day, value: 1, to: sunrise) ?? sunrise
            return .sunrise(nextDaySunrise)
        }
    }
}

struct SolarPathWidgetEntryView: View {
    var entry: SolarPathProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        SolarPathMediumView(entry: entry)
    }
}

// MARK: - Medium Widget (4x2)
struct SolarPathMediumView: View {
    let entry: SolarWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with city and time info
            HStack {
                VStack {
                    Text(entry.city)
                        .font(.system(size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.date.timeString(in: TimeZone(identifier: entry.timezoneIdentifier!)))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(nextEventText())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            
            // Sun path visualization (matching main app)
            GeometryReader { geometry in
                ZStack {
                    // Sun path arc (matching main app SunPathShape)
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        // Draw arc using the same sine curve as main app
                        let points = (0...20).map { i in
                            let progress = Double(i) / 20.0
                            let x = width * progress
                            let y = height - (height * 0.4 * sin(progress * .pi))
                            return CGPoint(x: x, y: y)
                        }
                        
                        if let firstPoint = points.first {
                            path.move(to: firstPoint)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    
                    // Current sun position (matching main app exactly)
                    Circle()
                        .fill(RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 1.0, blue: 0.8),
                                Color(red: 1.0, green: 0.92, blue: 0.23), // #FFEB3B
                                Color(red: 1.0, green: 0.84, blue: 0.0)    // #FFD600
                            ]),
                            center: .top,
                            startRadius: 12 * 0.075,
                            endRadius: 12 / 2
                        ))
                        .frame(width: 24, height: 24)
                        .shadow(color: .yellow.opacity(0.5), radius: 12, x: 0, y: 3)
                        .position(sunPosition(in: geometry.size))
                }
            }
            .frame(height: 70)
        }
        .padding(16)
        .fontDesign(.rounded)
    }
    
    private func sunPosition(in size: CGSize) -> CGPoint {
        // Calculate position using the same formula as main app
        let width = size.width
        let height = size.height
        let progress = entry.sunProgress
        
        // Exact same calculation as main app SunPathView
        let x = width * progress
        let y = height - (height * 0.4 * sin(progress * .pi))
        
        return CGPoint(x: x, y: y)
    }
    
    private func nextEventText() -> String {
        let now = entry.date
        let locationTimezone = TimeZone(identifier: entry.timezoneIdentifier!) ?? TimeZone.current
        
        switch entry.nextEvent {
        case .sunrise(let time):
            if time > now {
                return "Sunrise \(time.timeUntil())"
            } else {
                let elapsed = now.timeIntervalSince(time)
                if elapsed < 3600 { // Less than 1 hour
                    let minutes = Int(elapsed / 60)
                    return "Sunrise was \(minutes)m ago"
                } else {
                    let hours = Int(elapsed / 3600)
                    let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
                    if minutes > 0 {
                        return "Sunrise was \(hours)h \(minutes)m ago"
                    } else {
                        return "Sunrise was \(hours)h ago"
                    }
                }
            }
            
        case .solarNoon(let time):
            if time > now {
                return "Solar noon \(time.timeUntil())"
            } else {
                let elapsed = now.timeIntervalSince(time)
                if elapsed < 3600 {
                    let minutes = Int(elapsed / 60)
                    return "Solar noon was \(minutes)m ago"
                } else {
                    let hours = Int(elapsed / 3600)
                    let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
                    if minutes > 0 {
                        return "Solar noon was \(hours)h \(minutes)m ago"
                    } else {
                        return "Solar noon was \(hours)h ago"
                    }
                }
            }
            
        case .sunset(let time):
            if time > now {
                return "Sunset \(time.timeUntil())"
            } else {
                let elapsed = now.timeIntervalSince(time)
                if elapsed < 3600 {
                    let minutes = Int(elapsed / 60)
                    return "Sunset was \(minutes)m ago"
                } else {
                    let hours = Int(elapsed / 3600)
                    let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
                    if minutes > 0 {
                        return "Sunset was \(hours)h \(minutes)m ago"
                    } else {
                        return "Sunset was \(hours)h ago"
                    }
                }
            }
        }
    }
}

struct SolarEventCard: View {
    let icon: String
    let title: String
    let time: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            
            Text(time)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview(as: .systemMedium) {
    SolarPathWidget()
} timeline: {
    SolarWidgetEntry.placeholder()
}
