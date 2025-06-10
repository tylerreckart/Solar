//
//  Enums.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI
import Foundation

enum SkyCondition {
    case night
    case sunrise
    case daylight
    case sunset
}

enum DataLoadingState: Equatable {
    case idle
    case loading
    case success
    case error(message: String)

    static func == (lhs: DataLoadingState, rhs: DataLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.success, .success):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

enum UserDefaultsKeys {
    static let lastSelectedCityName = "lastSelectedCityName"
    static let lastSelectedCityLatitude = "lastSelectedCityLatitude"
    static let lastSelectedCityLongitude = "lastSelectedCityLongitude"
    static let lastSelectedCityTimezoneId = "lastSelectedCityTimezoneId"
    static let useCurrentLocation = "useCurrentLocation" // Add this new key
}

enum DataSectionType: String, CaseIterable, Codable, Identifiable {
    case solarDataList = "Today's Solar Forecast"
    case hourlyUVChart = "Hourly UV Forecast"
    case airQuality = "Air Quality"
    case solarCountdown = "Solar Timings"
    case goldenHour = "Golden Hour"

    var id: String { self.rawValue }
    
    var defaultSymbol: String {
        switch self {
        case .solarDataList:
            return "sun.max"
        case .hourlyUVChart:
            return "chart.bar.xaxis"
        case .airQuality:
            return "wind"
        case .solarCountdown:
            return "timer"
        case .goldenHour:
            return "sun.horizon"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .solarDataList:
            return AppColors.uvModerate
        case .hourlyUVChart:
            return AppColors.sunsetGradientStart
        case .airQuality:
            return AppColors.uvLow
        case .solarCountdown:
            return AppColors.primaryAccent
        case .goldenHour:
            return AppColors.uvModerate
        }
    }
}
