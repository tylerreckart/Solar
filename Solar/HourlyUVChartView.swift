//
//  HourlyUVChartView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/14/25.
//

import SwiftUI

struct HourlyUVChartView: View {
    let hourlyUVData: [SolarInfo.HourlyUV]
    let timezoneIdentifier: String? // To format time correctly

    // Formatter for hour display (e.g., "9AM", "1PM", "Now")
    private func timeString(for date: Date) -> String {
        let calendar = Calendar.current
        var effectiveTimeZone = TimeZone.current
        if let tzId = timezoneIdentifier, let tz = TimeZone(identifier: tzId) {
            effectiveTimeZone = tz
        }
        
        var tempCalendar = calendar
        tempCalendar.timeZone = effectiveTimeZone

        let now = Date()
        if tempCalendar.isDate(date, equalTo: now, toGranularity: .hour) {
            return "Now"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "ha" // "4PM"
        formatter.timeZone = effectiveTimeZone
        return formatter.string(from: date).lowercased()
    }

    // Constants for chart appearance
    private let maxUVForScale: Double = 12.0   // A reasonable max UV for visual scaling
    private let barMaxHeight: CGFloat = 80.0  // Max height for a bar
    private let barWidth: CGFloat = 35.0
    private let barCornerRadius: CGFloat = 6.0

    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hourly UV Forecast")
                    .font(.system(size: 16, weight: .semibold))
                if hourlyUVData.isEmpty {
                    Text("Hourly UV data is not available for the selected period.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(height: barMaxHeight + 50) // Keep consistent height
                } else {
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach(hourlyUVData) { uvItem in
                                VStack(spacing: 5) {
                                    Text(String(format: "%.0f", uvItem.uvIndex.rounded(.up))) // Show rounded UV value
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppColors.uvColor(for: uvItem.uvCategory))
                                    
                                    RoundedRectangle(cornerRadius: barCornerRadius)
                                        .fill(AppColors.uvColor(for: uvItem.uvCategory))
                                        .frame(width: barWidth, height: calculateBarHeight(for: uvItem.uvIndex))
                                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: uvItem.uvIndex) // Nice spring animation
                                    
                                    Text(timeString(for: uvItem.time))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                .id(uvItem.id)
                            }
                        }
                        .padding(.bottom, 5) // For hour labels
                    }
                    .frame(height: barMaxHeight + 50)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(AppColors.ui)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func calculateBarHeight(for uvIndex: Double) -> CGFloat {
        let clampedUV = max(0, min(uvIndex, maxUVForScale)) // Ensure UV is within 0 and maxUVForScale
        let proportion = clampedUV / maxUVForScale
        return max(5, proportion * barMaxHeight) // Ensure a minimum visible height for very low UV values
    }
}
