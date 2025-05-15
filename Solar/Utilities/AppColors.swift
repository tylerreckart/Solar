//
//  AppColors.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct AppColors {
    static let ui = Color("UIContainer")
    static let primaryAccent = Color("PrimaryAccentColor")
    static let background = Color("BackgroundColor")
    static let secondaryText = Color("SecondaryTextColor")
    static let error = Color("ErrorColor")

    static let sunriseGradientStart = Color("SunriseGradientStart")
    static let sunriseGradientEnd = Color("SunriseGradientEnd")
    static let daylightGradientStart = Color("DaylightGradientStart")
    static let daylightGradientEnd = Color("DaylightGradientEnd")
    static let sunsetGradientStart = Color("SunsetGradientStart")
    static let sunsetGradientEnd = Color("SunsetGradientEnd")
    static let nightGradientStart = Color("NightGradientStart")
    static let nightGradientEnd = Color("NightGradientEnd")

    static let uvLow = Color("UVLowColor")
    static let uvModerate = Color("UVModerateColor")
    static let uvHigh = Color("UVHighColor")
    static let uvVeryHigh = Color("UVVeryHighColor")
    static let uvExtreme = Color("UVExtremeColor")

    // Helper to get UV color based on index category
    static func uvColor(for category: String) -> Color {
        switch category.lowercased() {
        case "low": return uvLow
        case "moderate": return uvModerate
        case "high": return uvHigh
        case "very high": return uvVeryHigh
        case "extreme": return uvExtreme
        default: return secondaryText
        }
    }
}
