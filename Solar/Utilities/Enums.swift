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
