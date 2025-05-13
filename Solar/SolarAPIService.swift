//
//  SolarAPIService.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI
import CoreData
import CoreLocation
import Combine


struct OpenMeteoResponse: Codable {
    let latitude: Double
    let longitude: Double
    let daily: DailyData
    let daily_units: DailyUnits // Corrected from dailyUnits
}

struct DailyData: Codable {
    let time: [String] // Dates
    let sunrise: [String] // ISO8601 datetime strings
    let sunset: [String]  // ISO8601 datetime strings
    let uv_index_max: [Double?] // Max UV index for the day, can be null
}

struct DailyUnits: Codable { // To match JSON structure
    let time: String
    let sunrise: String
    let sunset: String
    let uv_index_max: String
}

class SolarAPIService {
    private let baseURL = "https://api.open-meteo.com/v1/forecast"
    private let isoDateFormatter = ISO8601DateFormatter() // For parsing sunrise/sunset strings

    init() {
        // ISO8601DateFormatter by default handles dates like "2023-11-21T07:00"
        // If your API returns only date "2023-11-21", you might need a DateFormatter with "yyyy-MM-dd"
    }

    func fetchSolarData(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        // Construct the URL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "daily", value: "sunrise,sunset,uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"), // Automatically determine timezone
            URLQueryItem(name: "forecast_days", value: "1") // Data for today
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        print("Fetching solar data from URL: \(url)")

        // Perform the request
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Error response body: \(dataString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Decode the JSON
        do {
            let decoder = JSONDecoder()
            // It's good practice to set a date decoding strategy if dates are not standard ISO8601 or require custom handling.
            // For "YYYY-MM-DDTHH:mm" strings, default ISO8601 should work.
            // For "YYYY-MM-DD" strings (like `daily.time`), a custom formatter might be needed if not just used as strings.
            let decodedResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            print("Successfully decoded solar data.")
            return decodedResponse
        } catch {
            print("JSON Decoding Error: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("Problematic JSON string: \(dataString)")
            }
            throw error // Re-throw the decoding error
        }
    }

    // Helper to parse ISO8601 date strings from API into Date objects
    func parseISOString(_ dateString: String) -> Date? {
        // Try with common ISO8601 formats
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                formatter.locale = Locale(identifier: "en_US_POSIX") // Essential for fixed-format dates
                // The timezone should ideally be the one the date string is in.
                // If OpenMeteo provides "2024-05-13T05:32" and the timezone for that data is America/New_York,
                // then this formatter should use that timezone.
                // However, ISO8601DateFormatter is generally better at handling these.
                // Setting to TimeZone.current assumes the string represents a time in the user's current system timezone,
                // which is correct if the API returns times adjusted to the user's local (via `timezone=auto`).
                formatter.timeZone = TimeZone.current
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        print("Could not parse date string: \(dateString)")
        return nil
    }
}
