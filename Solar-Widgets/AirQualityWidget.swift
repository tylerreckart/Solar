//
//  AirQualityWidget.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import WidgetKit
import SwiftUI

struct AirQualityWidget: Widget {
    let kind: String = "AirQualityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AirQualityProvider()) { entry in
            AirQualityWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        gradient: Gradient(colors: entry.aqiGradientColors()),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Air Quality")
        .description("Monitor air quality levels and health recommendations.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AirQualityProvider: TimelineProvider {
    private let sharedDataManager = SharedDataManager.shared
    private let apiService = WidgetSolarAPIService()
    
    func placeholder(in context: Context) -> AirQualityWidgetEntry {
        AirQualityWidgetEntry.placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (AirQualityWidgetEntry) -> ()) {
        Task {
            let entry = await fetchAirQualityWidgetEntry() ?? AirQualityWidgetEntry.placeholder()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AirQualityWidgetEntry>) -> ()) {
        Task {
            let entry = await fetchAirQualityWidgetEntry() ?? AirQualityWidgetEntry.placeholder()
            
            // Air quality doesn't change as rapidly, so fewer timeline entries
            var entries: [AirQualityWidgetEntry] = [entry]
            
            // Add entries for the next few time periods
            for minutesAhead in [15, 30, 60] {
                if let futureDate = Calendar.current.date(byAdding: .minute, value: minutesAhead, to: Date()) {
                    // Create new entry with updated date
                    let futureEntry = AirQualityWidgetEntry(
                        date: futureDate,
                        location: entry.location,
                        aqi: entry.aqi,
                        aqiCategory: entry.aqiCategory,
                        pm25: entry.pm25,
                        recommendation: entry.recommendation,
                        healthAlert: entry.healthAlert,
                        isDataStale: entry.isDataStale,
                        isLocationAuthorized: entry.isLocationAuthorized
                    )
                    entries.append(futureEntry)
                }
            }
            
            // Refresh every 45 minutes for air quality data with atEnd policy
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 45, to: Date()) ?? Date()
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
    
    private func fetchAirQualityWidgetEntry() async -> AirQualityWidgetEntry? {
        // Get location data from shared storage (now always returns a value with fallback)
        let location = sharedDataManager.getWidgetLocation()!
        
        do {
            // Fetch air quality data from API
            let airQualityData = try await apiService.fetchAirQualityData(
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            // Convert API response to widget entry
            return createAirQualityWidgetEntry(
                from: airQualityData,
                location: location
            )
            
        } catch {
            print("🔸 AirQualityWidget: Error fetching air quality data: \(error.localizedDescription)")
            return createErrorEntry(location: location, error: error)
        }
    }
    
    private func createAirQualityWidgetEntry(
        from airQualityData: WidgetAirQualityResponse,
        location: (latitude: Double, longitude: Double, city: String, timezone: String)
    ) -> AirQualityWidgetEntry {
        
        let now = Date()
        let aqi = airQualityData.current.usAqi
        let aqiCategory = airQualityData.aqiCategory
        let pm25 = airQualityData.current.pm25
        let recommendation = airQualityData.healthRecommendation
        
        // Determine health alert if AQI is high
        let healthAlert: String? = {
            guard let aqiValue = aqi else { return nil }
            if aqiValue > 150 {
                return "Air quality is unhealthy"
            }
            return nil
        }()
        
        return AirQualityWidgetEntry(
            date: now,
            location: location.city,
            aqi: aqi,
            aqiCategory: aqiCategory,
            pm25: pm25,
            recommendation: recommendation,
            healthAlert: healthAlert,
            isDataStale: false,
            isLocationAuthorized: true
        )
    }
    
    private func createLocationUnavailableEntry() -> AirQualityWidgetEntry {
        let now = Date()
        return AirQualityWidgetEntry(
            date: now,
            location: "Location Unavailable",
            aqi: nil,
            aqiCategory: "Unknown",
            pm25: nil,
            recommendation: "Enable location access",
            healthAlert: nil,
            isDataStale: false,
            isLocationAuthorized: false
        )
    }
    
    private func createErrorEntry(
        location: (latitude: Double, longitude: Double, city: String, timezone: String),
        error: Error
    ) -> AirQualityWidgetEntry {
        let now = Date()
        return AirQualityWidgetEntry(
            date: now,
            location: location.city,
            aqi: nil,
            aqiCategory: "Unknown",
            pm25: nil,
            recommendation: "Data unavailable",
            healthAlert: nil,
            isDataStale: true,
            isLocationAuthorized: true
        )
    }
}

struct AirQualityWidgetEntryView: View {
    var entry: AirQualityProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            AirQualitySmallView(entry: entry)
        case .systemMedium:
            AirQualityMediumView(entry: entry)
        case .systemLarge:
            AirQualityLargeView(entry: entry)
        default:
            AirQualityMediumView(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)
struct AirQualitySmallView: View {
    let entry: AirQualityWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Air quality icon
            Image(systemName: "wind")
                .font(.system(size: 20, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                
                // AQI value
                if let aqi = entry.aqi {
                    Text("\(aqi)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("--")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // AQI category
                Text(entry.aqiCategory)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Location
                Text(entry.location)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
        }
        .padding(12)
        .fontDesign(.rounded)
    }
    
    private func aqiGradientColors() -> [Color] {
        guard let aqi = entry.aqi else { return [.gray, .gray.opacity(0.7)] }
        
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
}

// MARK: - Medium Widget (4x2)
struct AirQualityMediumView: View {
    let entry: AirQualityWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - AQI info
            VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wind")
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                        
                        Text("Air Quality")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    if let aqi = entry.aqi {
                        Text("\(aqi)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("--")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text(entry.aqiCategory)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(entry.location)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Right side - Details and recommendation
                VStack(alignment: .trailing, spacing: 8) {
                    if let pm25 = entry.pm25 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PM2.5")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(pm25, specifier: "%.1f") µg/m³")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Health recommendation
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: healthIcon())
                            .font(.system(size: 14, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                        
                        Text(entry.recommendation)
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
        }
        .padding(16)
        .fontDesign(.rounded)
    }
    
    private func aqiGradientColors() -> [Color] {
        guard let aqi = entry.aqi else { return [.gray, .gray.opacity(0.7)] }
        
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
    
    private func healthIcon() -> String {
        guard let aqi = entry.aqi else { return "questionmark.circle.fill" }
        
        if aqi <= 50 {
            return "checkmark.circle.fill"
        } else if aqi <= 100 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.octagon.fill"
        }
    }
}

// MARK: - Large Widget (4x4)
struct AirQualityLargeView: View {
    let entry: AirQualityWidgetEntry
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "wind")
                                .font(.system(size: 18, weight: .medium))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.white)
                            
                            Text("Air Quality Index")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text(entry.location)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Updated")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(entry.date.timeString())
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Main AQI display
                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        if let aqi = entry.aqi {
                            Text("\(aqi)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("--")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(entry.aqiCategory)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // AQI scale indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("AQI Scale")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        AQIScaleView(currentAQI: entry.aqi)
                    }
                }
                
                // Detailed information
                VStack(spacing: 12) {
                    // PM2.5 and health info
                    HStack {
                        if let pm25 = entry.pm25 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PM2.5 Particles")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("\(pm25, specifier: "%.1f") µg/m³")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: healthIcon())
                                .font(.system(size: 16, weight: .medium))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.white)
                            
                            Text("Health Status")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // Health recommendation
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recommendation")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(entry.recommendation)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Health alert if present
                    if let alert = entry.healthAlert {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow)
                            
                            Text(alert)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.yellow)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
        }
        .padding(20)
        .fontDesign(.rounded)
    }
    
    private func aqiGradientColors() -> [Color] {
        guard let aqi = entry.aqi else { return [.gray, .gray.opacity(0.7)] }
        
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
    
    private func healthIcon() -> String {
        guard let aqi = entry.aqi else { return "questionmark.circle.fill" }
        
        if aqi <= 50 {
            return "checkmark.circle.fill"
        } else if aqi <= 100 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.octagon.fill"
        }
    }
}

// MARK: - AQI Scale Indicator
struct AQIScaleView: View {
    let currentAQI: Int?
    
    private let aqiRanges = [
        (range: 0...50, color: Color.green, label: "Good"),
        (range: 51...100, color: Color.yellow, label: "Moderate"),
        (range: 101...150, color: Color.orange, label: "Unhealthy for Sensitive"),
        (range: 151...200, color: Color.red, label: "Unhealthy"),
        (range: 201...300, color: Color.purple, label: "Very Unhealthy"),
        (range: 301...500, color: Color.brown, label: "Hazardous")
    ]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(0..<aqiRanges.count, id: \.self) { index in
                let range = aqiRanges[index]
                let isCurrentRange = currentAQI.map { range.range.contains($0) } ?? false
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(range.color)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: isCurrentRange ? 1 : 0)
                        )
                    
                    Text("\(range.range.lowerBound)-\(range.range.upperBound)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(isCurrentRange ? 1.0 : 0.7))
                        .fontWeight(isCurrentRange ? .semibold : .regular)
                }
            }
        }
    }
}

#Preview(as: .systemSmall) {
    AirQualityWidget()
} timeline: {
    AirQualityWidgetEntry.placeholder()
}

#Preview(as: .systemMedium) {
    AirQualityWidget()
} timeline: {
    AirQualityWidgetEntry.placeholder()
}

#Preview(as: .systemLarge) {
    AirQualityWidget()
} timeline: {
    AirQualityWidgetEntry.placeholder()
}
