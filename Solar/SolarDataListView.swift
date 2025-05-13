//
//  SolarDataListView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct SolarDataRow: View {
    let iconName: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 25, alignment: .center) // Fixed width for alignment
            Text(label)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundColor(.gray)
        }
    }
}

struct SolarDataListView: View {
    let solarInfo: SolarInfo
    @ObservedObject var viewModel: SunViewModel // For formatting time

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SolarDataRow(iconName: "sunrise.fill", label: "Sunrise", value: viewModel.formatTime(solarInfo.sunrise))
            SolarDataRow(iconName: "sunset.fill", label: "Sunset", value: viewModel.formatTime(solarInfo.sunset))
            SolarDataRow(iconName: "sun.max.fill", label: "Solar Noon", value: viewModel.formatTime(solarInfo.solarNoon))
            SolarDataRow(iconName: "timer", label: "Time to Noon", value: solarInfo.timeToSolarNoon)
            Divider()
            SolarDataRow(iconName: "arrow.up.and.down.circle.fill", label: "Altitude", value: String(format: "%.1f°", solarInfo.currentAltitude))
            SolarDataRow(iconName: "safari.fill", label: "Azimuth", value: String(format: "%.1f°", solarInfo.currentAzimuth))
            SolarDataRow(iconName: "sun.max.trianglebadge.exclamationmark.fill", label: "UV Index", value: "\(solarInfo.uvIndex) (\(solarInfo.uvIndexCategory))")
            Divider()
            SolarDataRow(iconName: "hourglass", label: "Daylight Duration", value: solarInfo.daylightDuration)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
