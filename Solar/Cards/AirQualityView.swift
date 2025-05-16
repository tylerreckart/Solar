//
//  AirQualityView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/15/25.
//

import SwiftUI

struct AirQualityView: View {
    let solarInfo: SolarInfo

    private var aqiColor: Color {
        guard let aqi = solarInfo.usAQI else { return AppColors.secondaryText }
        if aqi <= 50 { return Color.green } // Good
        if aqi <= 100 { return Color.yellow } // Moderate
        if aqi <= 150 { return Color.orange } // Unhealthy for Sensitive
        if aqi <= 200 { return Color.red } // Unhealthy
        if aqi <= 300 { return Color.purple } // Very Unhealthy
        return Color(hex: "#7E0023") // Hazardous (Maroon/Dark Red)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Air Quality")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 2)

            if let usAQI = solarInfo.usAQI {
                SolarDataRow(iconName: "aqi.medium", label: "US AQI", value: "\(usAQI) (\(solarInfo.usAQICategory))", valueColor: aqiColor)
            } else {
                SolarDataRow(iconName: "aqi.low", label: "US AQI", value: "N/A")
            }
            
            if let pm25 = solarInfo.pm2_5 {
                SolarDataRow(iconName: "smallcircle.filled.circle.fill", label: "PM2.5", value: String(format: "%.1f µg/m³", pm25))
            } else {
                SolarDataRow(iconName: "smallcircle.filled.circle.fill", label: "PM2.5", value: "N/A")
            }
        }
        .padding()
        .foregroundColor(.white)
        .background(AppColors.ui)
        .cornerRadius(16)
    }
}
