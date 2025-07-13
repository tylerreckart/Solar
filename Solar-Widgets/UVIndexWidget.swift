//
//  UVIndexWidget.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import WidgetKit
import SwiftUI

struct UVIndexWidget: Widget {
    let kind: String = "UVIndexWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UVIndexProvider()) { entry in
            UVIndexWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        gradient: Gradient(colors: entry.uvGradientColors()),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("UV Index")
        .description("Monitor UV levels and get sun protection recommendations.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UVIndexProvider: TimelineProvider {
    private let sharedDataManager = SharedDataManager.shared
    private let apiService = WidgetSolarAPIService()
    
    func placeholder(in context: Context) -> UVWidgetEntry {
        UVWidgetEntry.placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (UVWidgetEntry) -> ()) {
        Task {
            let entry = await fetchUVWidgetEntry() ?? UVWidgetEntry.placeholder()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UVWidgetEntry>) -> ()) {
        Task {
            let entry = await fetchUVWidgetEntry() ?? UVWidgetEntry.placeholder()
            
            // Create timeline entries for hourly updates since UV changes throughout the day
            var entries: [UVWidgetEntry] = [entry]
            
            // Add entries for the next few hours with updated UV data from hourly forecast
            for hour in 1...3 {
                if let futureDate = Calendar.current.date(byAdding: .hour, value: hour, to: Date()) {
                    var currentUV = entry.currentUV
                    var uvCategory = entry.uvCategory
                    var protectionAdvice = entry.protectionAdvice
                    
                    // Find UV value for this hour from the hourly forecast
                    if let hourlyUV = entry.hourlyForecast.first(where: { 
                        Calendar.current.isDate($0.time, equalTo: futureDate, toGranularity: .hour) 
                    }) {
                        currentUV = Int(round(hourlyUV.uvIndex))
                        uvCategory = getUVCategory(for: currentUV)
                        protectionAdvice = getProtectionAdvice(for: currentUV)
                    }
                    
                    // Create new entry with updated data
                    let futureEntry = UVWidgetEntry(
                        date: futureDate,
                        location: entry.location,
                        currentUV: currentUV,
                        uvCategory: uvCategory,
                        hourlyForecast: entry.hourlyForecast,
                        peakUVTime: entry.peakUVTime,
                        peakUVValue: entry.peakUVValue,
                        protectionAdvice: protectionAdvice,
                        isLocationAuthorized: entry.isLocationAuthorized
                    )
                    
                    entries.append(futureEntry)
                }
            }
            
            // Refresh every hour with atEnd policy for responsiveness
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
    
    private func fetchUVWidgetEntry() async -> UVWidgetEntry? {
        // Get location data from shared storage (now always returns a value with fallback)
        let location = sharedDataManager.getWidgetLocation()!
        
        do {
            // Fetch UV data from API
            let solarData = try await apiService.fetchSolarData(
                latitude: location.latitude,
                longitude: location.longitude,
                timezone: location.timezone
            )
            
            // Convert API response to widget entry
            return createUVWidgetEntry(
                from: solarData,
                location: location
            )
            
        } catch {
            print("🔸 UVIndexWidget: Error fetching UV data: \(error.localizedDescription)")
            return createErrorEntry(location: location, error: error)
        }
    }
    
    private func createUVWidgetEntry(
        from solarData: WidgetSolarResponse,
        location: (latitude: Double, longitude: Double, city: String, timezone: String)
    ) -> UVWidgetEntry {
        
        let now = Date()
        let currentUV = Int(round(solarData.current.uvIndex ?? 0.0))
        let maxUV = Int(round(solarData.daily.uvIndexMax.first ?? 0.0))
        let hourlyData = solarData.getHourlyUVData()
        
        // Find peak UV time (approximate from hourly data)
        let peakUVTime = hourlyData.max(by: { $0.uvIndex < $1.uvIndex })?.time
        
        // Generate UV category
        let uvCategory = getUVCategory(for: currentUV)
        
        // Generate protection advice
        let protectionAdvice = getProtectionAdvice(for: currentUV)
        
        return UVWidgetEntry(
            date: now,
            location: location.city,
            currentUV: currentUV,
            uvCategory: uvCategory,
            hourlyForecast: hourlyData,
            peakUVTime: peakUVTime,
            peakUVValue: maxUV,
            protectionAdvice: protectionAdvice,
            isLocationAuthorized: true
        )
    }
    
    private func createLocationUnavailableEntry() -> UVWidgetEntry {
        let now = Date()
        return UVWidgetEntry(
            date: now,
            location: "Location Unavailable",
            currentUV: 0,
            uvCategory: "Unknown",
            hourlyForecast: [],
            peakUVTime: nil,
            peakUVValue: 0,
            protectionAdvice: "Enable location access",
            isLocationAuthorized: false
        )
    }
    
    private func createErrorEntry(
        location: (latitude: Double, longitude: Double, city: String, timezone: String),
        error: Error
    ) -> UVWidgetEntry {
        let now = Date()
        return UVWidgetEntry(
            date: now,
            location: location.city,
            currentUV: 0,
            uvCategory: "Unknown",
            hourlyForecast: [],
            peakUVTime: nil,
            peakUVValue: 0,
            protectionAdvice: "Data unavailable",
            isLocationAuthorized: true
        )
    }
    
    private func getUVCategory(for uvIndex: Int) -> String {
        if uvIndex >= 11 { return "Extreme" }
        else if uvIndex >= 8 { return "Very High" }
        else if uvIndex >= 6 { return "High" }
        else if uvIndex >= 3 { return "Moderate" }
        else { return "Low" }
    }
    
    private func getProtectionAdvice(for uvIndex: Int) -> String {
        if uvIndex <= 2 { return "Minimal protection needed" }
        else if uvIndex <= 5 { return "Use sunscreen, wear a hat" }
        else if uvIndex <= 7 { return "Seek shade, wear protective clothing" }
        else if uvIndex <= 10 { return "Avoid sun 10am-4pm, use SPF 30+" }
        else { return "Stay indoors or in shade" }
    }
}

struct UVIndexWidgetEntryView: View {
    var entry: UVIndexProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            UVIndexSmallView(entry: entry)
        case .systemMedium:
            UVIndexMediumView(entry: entry)
        default:
            UVIndexMediumView(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)
struct UVIndexSmallView: View {
    let entry: UVWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // UV sun icon
            Image(systemName: uvIcon())
                .font(.system(size: 20, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
            
            // UV Index value
            Text("\(entry.currentUV)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // UV category
            Text(entry.uvCategory)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Peak time if applicable
            if let peakTime = entry.peakUVTime, entry.peakUVValue > entry.currentUV {
                Text("Peak \(peakTime.timeString())")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text(entry.location)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .fontDesign(.rounded)
    }
    
    private func uvGradientColors() -> [Color] {
        let uv = entry.currentUV
        
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
    
    private func uvIcon() -> String {
        let uv = entry.currentUV
        
        if uv <= 2 {
            return "sun.min.fill"
        } else if uv <= 5 {
            return "sun.max.fill"
        } else if uv <= 7 {
            return "sun.max.trianglebadge.exclamationmark.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Medium Widget (4x2)
struct UVIndexMediumView: View {
    let entry: UVWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                    HStack {
                        Image(systemName: uvIcon())
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                        
                        Text("UV Index")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Text(entry.location)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Main UV display and chart
                HStack(spacing: 16) {
                    // Current UV
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.currentUV)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(entry.uvCategory)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if let peakTime = entry.peakUVTime {
                            Text("Peak at \(peakTime.timeString())")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Protection advice
                    VStack(alignment: .trailing) {
                        Spacer()
                        
                        Image(systemName: protectionIcon())
                            .font(.system(size: 14, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                        
                        Text(entry.protectionAdvice)
                            .font(.caption)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
        }
        .padding(16)
        .fontDesign(.rounded)
    }
    
    private func uvGradientColors() -> [Color] {
        let uv = entry.currentUV
        
        if uv <= 2 {
            return [.green, .mint]
        } else if uv <= 5 {
            return [.yellow, .orange.opacity(0.9)]
        } else if uv <= 7 {
            return [.orange, .red.opacity(0.7)]
        } else if uv <= 10 {
            return [.red, .pink]
        } else {
            return [.purple, .indigo]
        }
    }
    
    private func uvIcon() -> String {
        let uv = entry.currentUV
        
        if uv <= 2 {
            return "sun.min.fill"
        } else if uv <= 5 {
            return "sun.max.fill"
        } else if uv <= 7 {
            return "sun.max.trianglebadge.exclamationmark.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func protectionIcon() -> String {
        let uv = entry.currentUV
        
        if uv <= 2 {
            return "checkmark.shield.fill"
        } else if uv <= 5 {
            return "shield.fill"
        } else {
            return "exclamationmark.shield.fill"
        }
    }
}

// MARK: - UV Scale View
struct UVScaleView: View {
    let currentUV: Int
    
    private let uvRanges = [
        (range: 0...2, color: Color.green, label: "Low"),
        (range: 3...5, color: Color.yellow, label: "Moderate"),
        (range: 6...7, color: Color.orange, label: "High"),
        (range: 8...10, color: Color.red, label: "Very High"),
        (range: 11...15, color: Color.purple, label: "Extreme")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<uvRanges.count, id: \.self) { index in
                let range = uvRanges[index]
                let isCurrentRange = range.range.contains(currentUV)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(range.color)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: isCurrentRange ? 1 : 0)
                        )
                    
                    Text(range.label)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(isCurrentRange ? 1.0 : 0.7))
                        .fontWeight(isCurrentRange ? .semibold : .regular)
                }
            }
        }
    }
}

#Preview(as: .systemSmall) {
    UVIndexWidget()
} timeline: {
    UVWidgetEntry.placeholder()
}

#Preview(as: .systemMedium) {
    UVIndexWidget()
} timeline: {
    UVWidgetEntry.placeholder()
}
