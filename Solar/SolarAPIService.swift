//
//  SolarAPIService.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import Foundation
import CoreLocation

// Updated OpenMeteoResponse to capture the timezone identifier
struct OpenMeteoResponse: Codable {
    let latitude: Double
    let longitude: Double
    let utc_offset_seconds: Int // Timezone offset from GMT time in seconds
    let timezone: String // Timezone name like Europe/Berlin
    let timezone_abbreviation: String // Abbreviation like CET
    let daily: DailyData
    let daily_units: DailyUnits
    let hourly: HourlyData?
}

struct DailyData: Codable {
    let time: [String]
    let sunrise: [String]
    let sunset: [String]
    let uv_index_max: [Double?]
}

struct DailyUnits: Codable {
    let time: String
    let sunrise: String
    let sunset: String
    let uv_index_max: String
    let weathercode: String?
    let cloudcover: String?
}

struct HourlyData: Codable {
    let time: [String]
    let weathercode: [Int]?
    let cloudcover: [Int]?
}


class SolarAPIService {
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    
    // Formatter for "YYYY-MM-DD"
    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Crucial for fixed formats
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Interpret date string as UTC date part
        return formatter
    }()

    // Formatter for "YYYY-MM-DD'T'HH:mm" (local wall time from API)
    private let localTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Crucial for fixed formats
        // Timezone will be set dynamically before parsing based on API response
        return formatter
    }()


    func fetchSolarData(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "daily", value: "sunrise,sunset,uv_index_max"),
            URLQueryItem(name: "hourly", value: "weathercode,cloudcover"),
            URLQueryItem(name: "timezone", value: "auto"), // API will return timezone info
            URLQueryItem(name: "forecast_days", value: "1")
        ]

        guard let url = components.url else {
            print("❌ SolarAPIService: Bad URL constructed: \(components.string ?? "N/A")")
            throw APIError.badURL
        }
        
        print("☀️ SolarAPIService: Fetching solar data from URL: \(url)")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ SolarAPIService: Not an HTTP response.")
            throw APIError.networkError(description: "Invalid server response.")
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ SolarAPIService: HTTP Error: \(httpResponse.statusCode). Body: \(responseBody)")
            throw APIError.badServerResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            print("✅ SolarAPIService: Successfully decoded solar data for timezone: \(decodedResponse.timezone)")
            return decodedResponse
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("❌ SolarAPIService: JSON Decoding Error: \(error.localizedDescription).")
            print("Problematic JSON string: \(responseBody)")
            throw APIError.decodingError(description: error.localizedDescription, data: data)
        }
    }

    // Updated to take timezoneIdentifier for correct parsing of local wall times
    func parseDateTimeString(_ dateString: String, timezoneIdentifier: String) -> Date? {
        // Set the timezone on the formatter for this specific parsing operation
        // This tells the formatter: "This dateString represents a wall clock time in this specific timezone"
        // The resulting `Date` object will be the correct absolute point in time (UTC).
        if let tz = TimeZone(identifier: timezoneIdentifier) {
            localTimeFormatter.timeZone = tz
            if let date = localTimeFormatter.date(from: dateString) {
                return date
            }
        } else {
            print("⚠️ SolarAPIService: Could not create TimeZone for identifier: \(timezoneIdentifier)")
            // Fallback: try parsing as if it's in current device timezone, or UTC, though less accurate
            localTimeFormatter.timeZone = TimeZone.current
            if let date = localTimeFormatter.date(from: dateString) {
                 print("⚠️ SolarAPIService: Parsed \(dateString) using current device timezone as fallback.")
                return date
            }
        }
        print("⚠️ SolarAPIService: Could not parse date-time string: \(dateString) with timezone \(timezoneIdentifier)")
        return nil
    }
    
    func parseDateOnlyString(_ dateString: String) -> Date? {
        // dateOnlyFormatter is already set to interpret the date string as UTC for the date part
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        print("⚠️ SolarAPIService: Could not parse date-only string: \(dateString)")
        return nil
    }
}

// APIError enum remains the same
enum APIError: Error, LocalizedError {
    case badURL
    case networkError(description: String)
    case badServerResponse(statusCode: Int, responseBody: String?)
    case decodingError(description: String, data: Data?)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "The URL for the request was invalid."
        case .networkError(let description):
            return "Network error: \(description)"
        case .badServerResponse(let statusCode, _):
            return "Server returned an error: \(statusCode)."
        case .decodingError(let description, _):
            return "Failed to decode the response: \(description)."
        }
    }
}
