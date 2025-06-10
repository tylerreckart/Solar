//
//  WidgetSolarAPIService.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import Foundation
import CoreLocation

/// API service for fetching solar data specifically for widgets
public class WidgetSolarAPIService {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    init() {
        // Configure the decoder with date formatting
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        decoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    /// Fetches solar data for the given location
    func fetchSolarData(
        latitude: Double,
        longitude: Double,
        timezone: String
    ) async throws -> WidgetSolarResponse {
        
        // Build URL for Open-Meteo API
        var urlComponents = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "daily", value: "sunrise,sunset,uv_index_max,uv_index_clear_sky_max"),
            URLQueryItem(name: "hourly", value: "uv_index,uv_index_clear_sky"),
            URLQueryItem(name: "current", value: "uv_index"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        
        guard let url = urlComponents.url else {
            throw WidgetAPIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WidgetAPIError.networkError
        }
        
        do {
            let apiResponse = try decoder.decode(WidgetSolarResponse.self, from: data)
            return apiResponse
        } catch {
            throw WidgetAPIError.decodingError(error)
        }
    }
    
    /// Fetches air quality data for the given location
    func fetchAirQualityData(
        latitude: Double,
        longitude: Double
    ) async throws -> WidgetAirQualityResponse {
        
        var urlComponents = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "us_aqi,pm2_5"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        
        guard let url = urlComponents.url else {
            throw WidgetAPIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WidgetAPIError.networkError
        }
        
        do {
            let apiResponse = try decoder.decode(WidgetAirQualityResponse.self, from: data)
            return apiResponse
        } catch {
            throw WidgetAPIError.decodingError(error)
        }
    }
}

// MARK: - Error Types

enum WidgetAPIError: Error, LocalizedError {
    case invalidURL
    case networkError
    case decodingError(Error)
    case noLocationData
    case staleData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network request failed"
        case .decodingError(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .noLocationData:
            return "No location data available"
        case .staleData:
            return "Location data is too old"
        }
    }
}

// MARK: - Response Models

struct WidgetSolarResponse: Codable {
    let daily: DailySolarData
    let hourly: HourlySolarData
    let current: CurrentSolarData
    
    struct DailySolarData: Codable {
        let sunrise: [String]
        let sunset: [String]
        let uvIndexMax: [Double]
        let uvIndexClearSkyMax: [Double]
        
        enum CodingKeys: String, CodingKey {
            case sunrise, sunset
            case uvIndexMax = "uv_index_max"
            case uvIndexClearSkyMax = "uv_index_clear_sky_max"
        }
    }
    
    struct HourlySolarData: Codable {
        let time: [String]
        let uvIndex: [Double?]
        let uvIndexClearSky: [Double?]
        
        enum CodingKeys: String, CodingKey {
            case time
            case uvIndex = "uv_index"
            case uvIndexClearSky = "uv_index_clear_sky"
        }
    }
    
    struct CurrentSolarData: Codable {
        let uvIndex: Double?
        
        enum CodingKeys: String, CodingKey {
            case uvIndex = "uv_index"
        }
    }
}

struct WidgetAirQualityResponse: Codable {
    let current: CurrentAirQualityData
    
    struct CurrentAirQualityData: Codable {
        let usAqi: Int?
        let pm25: Double?
        
        enum CodingKeys: String, CodingKey {
            case usAqi = "us_aqi"
            case pm25 = "pm2_5"
        }
    }
}

// MARK: - Utility Extensions

extension WidgetSolarResponse {
    /// Get sunrise date for today
    var todaySunrise: Date? {
        guard let sunriseString = daily.sunrise.first else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: sunriseString)
    }
    
    /// Get sunset date for today
    var todaySunset: Date? {
        guard let sunsetString = daily.sunset.first else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: sunsetString)
    }
    
    /// Get solar noon (calculated as midpoint between sunrise and sunset)
    var solarNoon: Date? {
        guard let sunrise = todaySunrise,
              let sunset = todaySunset else { return nil }
        let midpoint = sunrise.timeIntervalSince1970 + (sunset.timeIntervalSince1970 - sunrise.timeIntervalSince1970) / 2
        return Date(timeIntervalSince1970: midpoint)
    }
    
    /// Get hourly UV data for the next 8 hours
    func getHourlyUVData() -> [WidgetHourlyUV] {
        let now = Date()
        var hourlyData: [WidgetHourlyUV] = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        for (index, timeString) in hourly.time.enumerated() {
            guard let time = formatter.date(from: timeString),
                  time >= now,
                  hourlyData.count < 8,
                  index < hourly.uvIndex.count,
                  let uvIndex = hourly.uvIndex[index] else { continue }
            
            hourlyData.append(WidgetHourlyUV(time: time, uvIndex: uvIndex))
        }
        
        return hourlyData
    }
}

extension WidgetAirQualityResponse {
    /// Get AQI category string
    var aqiCategory: String {
        guard let aqi = current.usAqi else { return "N/A" }
        if aqi <= 50 { return "Good" }
        if aqi <= 100 { return "Moderate" }
        if aqi <= 150 { return "Unhealthy for Sensitive Groups" }
        if aqi <= 200 { return "Unhealthy" }
        if aqi <= 300 { return "Very Unhealthy" }
        return "Hazardous"
    }
    
    /// Get health recommendation based on AQI
    var healthRecommendation: String {
        guard let aqi = current.usAqi else { return "Data unavailable" }
        if aqi <= 50 { return "Great for outdoor activities" }
        if aqi <= 100 { return "Limit outdoor activities" }
        if aqi <= 150 { return "Unhealthy for sensitive groups" }
        if aqi <= 200 { return "Avoid outdoor activities" }
        if aqi <= 300 { return "Stay indoors" }
        return "Emergency conditions"
    }
}
