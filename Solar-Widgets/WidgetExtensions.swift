//
//  WidgetExtensions.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import SwiftUI
import WidgetKit

// MARK: - Color Extensions for Widgets

extension Color {
    /// Sky gradient colors matching main app exactly
    static func skyGradientColors(for skyCondition: SkyCondition) -> [Color] {
        switch skyCondition {
        case .sunrise:
            return [
                Color(red: 255/255, green: 167/255, blue: 185/255),    // SunriseGradientStart
                Color(red: 255/255, green: 209/255, blue: 194/255)     // SunriseGradientEnd
            ]
        case .daylight:
            return [
                Color(red: 29/255, green: 159/255, blue: 247/255),     // DaylightGradientStart
                Color(red: 150/255, green: 217/255, blue: 237/255)     // DaylightGradientEnd
            ]
        case .sunset:
            return [
                Color(red: 207/255, green: 55/255, blue: 106/255),     // SunsetGradientStart
                Color(red: 255/255, green: 140/255, blue: 0/255)       // SunsetGradientEnd
            ]
        case .night:
            return [
                Color(red: 0/255, green: 0/255, blue: 50/255),         // NightGradientStart
                Color(red: 25/255, green: 25/255, blue: 112/255)       // NightGradientEnd
            ]
        }
    }
    
    /// Creates dynamic gradients based on time of day for Solar Path widgets
    static func timeOfDayGradient(progress: Double) -> [Color] {
        if progress < 0.15 { // Early morning
            return [.indigo, .purple, .pink]
        } else if progress < 0.3 { // Sunrise
            return [.orange, .pink, .yellow]
        } else if progress < 0.7 { // Daylight
            return [.cyan, .blue, .mint]
        } else if progress < 0.85 { // Sunset
            return [.pink, .orange, .purple]
        } else { // Night
            return [.indigo, .black, .purple]
        }
    }
    
    /// Enhanced UV color mapping with gradient support
    static func uvGradient(for uvIndex: Int) -> [Color] {
        if uvIndex <= 2 {
            return [.green, .mint]
        } else if uvIndex <= 5 {
            return [.yellow, .orange.opacity(0.8)]
        } else if uvIndex <= 7 {
            return [.orange, .red.opacity(0.8)]
        } else if uvIndex <= 10 {
            return [.red, .pink]
        } else {
            return [.purple, .indigo]
        }
    }
    
    /// AQI color gradients with health-based colors
    static func aqiGradient(for aqi: Int) -> [Color] {
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

// MARK: - View Modifiers for Widgets

struct WidgetCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 4) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: shadowRadius)
            )
    }
}

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius * 0.5)
    }
}

extension View {
    func widgetCardStyle(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 4) -> some View {
        modifier(WidgetCardStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    func glowEffect(color: Color, radius: CGFloat = 4, intensity: Double = 0.6) -> some View {
        modifier(GlowEffect(color: color, radius: radius, intensity: intensity))
    }
}

// MARK: - Widget Utility Functions

struct WidgetUtilities {
    /// Calculates the next significant solar event
    static func nextSolarEvent(sunrise: Date, solarNoon: Date, sunset: Date) -> SolarEvent {
        let now = Date()
        
        if now < sunrise {
            return .sunrise(sunrise)
        } else if now < solarNoon {
            return .solarNoon(solarNoon)
        } else if now < sunset {
            return .sunset(sunset)
        } else {
            // If past sunset, show tomorrow's sunrise
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: sunrise) ?? sunrise
            return .sunrise(tomorrow)
        }
    }
    
    /// Formats time difference for widget display
    static func formatTimeUntil(_ targetDate: Date) -> String {
        let now = Date()
        let interval = targetDate.timeIntervalSince(now)
        
        if interval <= 0 { return "Now" }
        if interval < 60 { return "< 1m" }
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Gets health recommendation based on AQI
    static func healthRecommendation(for aqi: Int?) -> String {
        guard let aqi = aqi else { return "Data unavailable" }
        
        if aqi <= 50 {
            return "Great for outdoor activities"
        } else if aqi <= 100 {
            return "Moderate - sensitive groups should limit prolonged outdoor exertion"
        } else if aqi <= 150 {
            return "Unhealthy for sensitive groups - limit outdoor time"
        } else if aqi <= 200 {
            return "Unhealthy - avoid outdoor activities"
        } else if aqi <= 300 {
            return "Very unhealthy - stay indoors"
        } else {
            return "Hazardous - emergency conditions"
        }
    }
    
    /// Gets UV protection advice
    static func uvProtectionAdvice(for uvIndex: Int) -> String {
        if uvIndex <= 2 {
            return "Minimal protection needed"
        } else if uvIndex <= 5 {
            return "Use sunscreen, wear a hat"
        } else if uvIndex <= 7 {
            return "Seek shade, wear protective clothing"
        } else if uvIndex <= 10 {
            return "Avoid sun 10am-4pm, use SPF 30+"
        } else {
            return "Stay indoors or in shade"
        }
    }
    
    /// Calculates accurate sun position using astronomical data
    static func accurateSunPositionOnArc(solarPathData: SolarPathData, arcSize: CGSize, xInsetFactor: CGFloat = 0.1, yBaseFactor: CGFloat = 0.85) -> CGPoint {
        let rect = CGRect(origin: .zero, size: arcSize)
        return SunPositionCalculator.calculateAccurateSunPosition(
            solarPathData: solarPathData,
            in: rect,
            xInsetFactor: xInsetFactor,
            yBaseFactor: yBaseFactor
        )
    }
    
    /// Fallback: Calculates sun position on arc for visualization (legacy method)
    static func sunPositionOnArc(progress: Double, arcSize: CGSize) -> CGPoint {
        let width = arcSize.width
        let height = arcSize.height
        
        // Quadratic bezier curve calculation
        let x = width * progress
        let y = height * (1 - 4 * progress * (1 - progress))
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Animation Helpers

extension Animation {
    static let smoothWidgetTransition = Animation.easeInOut(duration: 0.8)
    static let sunGlow = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let dataUpdate = Animation.easeOut(duration: 0.6)
}

// MARK: - Widget Content Unavailable States

struct WidgetLocationDisabled: View {
    let widgetFamily: WidgetFamily
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.gray, .gray.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: iconSpacing) {
                Image(systemName: "location.slash")
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.white)
                
                if widgetFamily != .systemSmall {
                    Text("Location Disabled")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Enable in Settings")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
        }
    }
    
    private var iconSize: CGFloat {
        switch widgetFamily {
        case .systemSmall: return 20
        case .systemMedium: return 24
        case .systemLarge: return 28
        default: return 24
        }
    }
    
    private var iconSpacing: CGFloat {
        switch widgetFamily {
        case .systemSmall: return 4
        case .systemMedium: return 6
        case .systemLarge: return 8
        default: return 6
        }
    }
}

struct WidgetDataUnavailable: View {
    let title: String
    let message: String
    let widgetFamily: WidgetFamily
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.gray, .gray.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.white)
                
                if widgetFamily != .systemSmall {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(12)
        }
    }
    
    private var iconSize: CGFloat {
        switch widgetFamily {
        case .systemSmall: return 18
        case .systemMedium: return 22
        case .systemLarge: return 26
        default: return 22
        }
    }
}
