//
//  GoldenHourView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/15/25.
//

import SwiftUI

struct GoldenHourView: View {
    let solarInfo: SolarInfo
    let viewModel: SunViewModel // For time formatting

    private func format(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        return viewModel.formatTime(date)
    }
    
    private func formatRange(_ date1: Date?, _ date2: Date?) -> String {
        guard let d1 = date1, let d2 = date2 else { return "N/A" }
        if d1 > d2 { return "\(format(d2)) - \(format(d1))" } // Ensure correct order
        return "\(format(d1)) - \(format(d2))"
    }

    // Approximations
    var morningBlueHour: String { formatRange(solarInfo.civilTwilightBegin, solarInfo.sunrise) }
    var morningGoldenHour: String {
        let sunriseEndGolden = Calendar.current.date(byAdding: .hour, value: 1, to: solarInfo.sunrise)
        return formatRange(solarInfo.sunrise, sunriseEndGolden)
    }
    var eveningGoldenHour: String {
        let sunsetStartGolden = Calendar.current.date(byAdding: .hour, value: -1, to: solarInfo.sunset)
        return formatRange(sunsetStartGolden, solarInfo.sunset)
    }
    var eveningBlueHour: String { formatRange(solarInfo.sunset, solarInfo.civilTwilightEnd) }


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Golden Hour")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 2)
            Text("(Approximate times based on twilight & sunrise/sunset)")
                .font(.caption2)
                .foregroundColor(AppColors.secondaryText)
                .padding(.bottom, 4)
            
            SolarDataRow(iconName: "sun.lefthalf.filled", label: "Morning Golden Hour", value: morningGoldenHour)
            SolarDataRow(iconName: "sun.righthalf.filled", label: "Evening Golden Hour", value: eveningGoldenHour)
        }
        .padding()
        .foregroundColor(.white)
        .background(AppColors.ui)
        .cornerRadius(16)
    }
}
