//
//  Enums.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import Foundation

enum SkyCondition {
    case night
    case sunrise
    case daylight
    case sunset
}

enum DataLoadingState {
    case idle
    case loading
    case success
    case error(message: String)
}

enum UserDefaultsKeys {
    static let lastSelectedCityName = "lastSelectedCityName"
    static let lastSelectedCityLatitude = "lastSelectedCityLatitude"
    static let lastSelectedCityLongitude = "lastSelectedCityLongitude"
    static let lastSelectedCityTimezoneId = "lastSelectedCityTimezoneId"
}

enum DataSectionType: String, CaseIterable, Codable, Identifiable {
    case solarDataList = "Today's Solar Forecast"
    case hourlyUVChart = "Hourly UV Forecast"
    case airQuality = "Air Quality"
    case solarCountdown = "Solar Timings"
    case goldenHour = "Golden Hour" 

    var id: String { self.rawValue }
}
