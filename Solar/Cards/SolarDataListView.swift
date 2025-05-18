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
    var valueColor: Color = AppColors.secondaryText

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(AppColors.primaryAccent)
                .frame(width: 28, alignment: .center)
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
    }
}

struct SolarDataListView: View {
    let solarInfo: SolarInfo
    @ObservedObject var viewModel: SunViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Today's Solar Forecast")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 5)
            VStack {
                SolarDataRow(iconName: "sunrise.fill", label: "Sunrise", value: viewModel.formatTime(solarInfo.sunrise))
                SolarDataRow(iconName: "sunset.fill", label: "Sunset", value: viewModel.formatTime(solarInfo.sunset))
                SolarDataRow(iconName: "sun.max.fill", label: "Solar Noon", value: viewModel.formatTime(solarInfo.solarNoon))
                SolarDataRow(iconName: "arrow.up.and.down.circle.fill", label: "Altitude", value: String(format: "%.1f°", solarInfo.currentAltitude))
                SolarDataRow(iconName: "safari.fill", label: "Azimuth", value: String(format: "%.1f°", solarInfo.currentAzimuth))
                SolarDataRow(iconName: "sun.max.trianglebadge.exclamationmark.fill",
                             label: "Daily UV Index",
                             value: "\(solarInfo.uvIndex) (\(solarInfo.uvIndexCategory))",
                             valueColor: AppColors.uvColor(for: solarInfo.uvIndexCategory))
                SolarDataRow(iconName: "hourglass", label: "Daylight Duration", value: solarInfo.daylightDuration)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(AppColors.ui)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}
