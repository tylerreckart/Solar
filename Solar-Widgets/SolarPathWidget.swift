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
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Solar Path")
        .description("Track the sun's journey across the sky with sunrise and sunset times.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
            
            // Add entries for the next few hours to show sun progress
            let calendar = Calendar.current
            for minutesAhead in [5, 15, 30, 60] {
                if let futureDate = calendar.date(byAdding: .minute, value: minutesAhead, to: Date()) {
                    // Recalculate sun progress for future time
                    let totalDaylight = entry.sunset.timeIntervalSince(entry.sunrise)
                    let elapsed = futureDate.timeIntervalSince(entry.sunrise)
                    let futureProgress = totalDaylight > 0 ? max(0.0, min(1.0, elapsed / totalDaylight)) : 0.5
                    
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
                        skyCondition: entry.skyCondition,
                        nextEvent: entry.nextEvent,
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
        
        let now = Date()
        let sunrise = solarData.todaySunrise ?? now
        let sunset = solarData.todaySunset ?? now
        let solarNoon = solarData.solarNoon ?? now
        
        // Calculate sun position using the enhanced calculator
        let sunPosition = SunPositionCalculator.calculateSunPosition(
            date: now,
            latitude: location.latitude,
            longitude: location.longitude,
            timezoneIdentifier: location.timezone
        )
        
        // Determine sky condition based on time
        let skyCondition = determineSkyCondition(
            currentTime: now,
            sunrise: sunrise,
            sunset: sunset
        )
        
        // Calculate next solar event
        let nextEvent = determineNextSolarEvent(
            currentTime: now,
            sunrise: sunrise,
            solarNoon: solarNoon,
            sunset: sunset
        )
        
        // Calculate sun progress
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
        sunset: Date
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
        sunset: Date
    ) -> SolarEvent {
        if currentTime < sunrise {
            return .sunrise(sunrise)
        } else if currentTime < solarNoon {
            return .solarNoon(solarNoon)
        } else if currentTime < sunset {
            return .sunset(sunset)
        } else {
            // Next day's sunrise
            let nextDaySunrise = Calendar.current.date(byAdding: .day, value: 1, to: sunrise) ?? sunrise
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
        VStack(spacing: 8) {
            // Header with city
            HStack {
                    Text(entry.city)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(entry.date.timeString())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Sun path visualization
                GeometryReader { geometry in
                    ZStack {
                        // Sun path arc
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            // Draw a simpler arc using points along the sine curve
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
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                        
                        // Solar noon indicator
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.6)
                        
                        // Current sun position
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [.yellow, .orange]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 6
                                )
                            )
                            .frame(width: 12, height: 12)
                            .position(sunPosition(in: geometry.size))
                            .shadow(color: .yellow.opacity(0.8), radius: 3)
                    }
                }
                .frame(height: 60)
        }
        .padding(16)
    }
    
    private func sunPosition(in size: CGSize) -> CGPoint {
        // Calculate position on a simpler, less exaggerated curve
        let width = size.width
        let height = size.height
        let progress = entry.sunProgress
        
        // Simple arc calculation with less dramatic curve
        let x = width * progress
        let y = height - (height * 0.4 * sin(progress * .pi)) // Less exaggerated arc
        
        return CGPoint(x: x, y: y)
    }
}

struct SolarEventCard: View {
    let icon: String
    let title: String
    let time: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            
            Text(time)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview(as: .systemMedium) {
    SolarPathWidget()
} timeline: {
    SolarWidgetEntry.placeholder()
}
