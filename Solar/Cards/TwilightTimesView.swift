//
//  TwilightTimesView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/15/25.
//

import SwiftUI

struct TwilightTimesView: View {
    let solarInfo: SolarInfo
    let viewModel: SunViewModel // For time formatting

    private func format(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        return viewModel.formatTime(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Twilight Phases")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 2)

            SolarDataRow(iconName: "sun.haze.fill", label: "Civil Twilight", value: "\(format(solarInfo.civilTwilightBegin)) - \(format(solarInfo.civilTwilightEnd))")
            SolarDataRow(iconName: "moon.haze.fill", label: "Nautical Twilight", value: "\(format(solarInfo.nauticalTwilightBegin)) - \(format(solarInfo.nauticalTwilightEnd))")
            SolarDataRow(iconName: "stars.fill", label: "Astronomical Twilight", value: "\(format(solarInfo.astronomicalTwilightBegin)) - \(format(solarInfo.astronomicalTwilightEnd))")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// Solar/MoonInfoView.swift
import SwiftUI

struct MoonInfoView: View {
    let solarInfo: SolarInfo
    let viewModel: SunViewModel // For time formatting

    private func format(_ date: Date?) -> String {
        guard let date = date else { return "N/A" } // Or "Not today" if API provides dates outside current
        return viewModel.formatTime(date)
    }

    // Basic SF Symbol mapping for moon phase
    private var moonPhaseSymbol: String {
        guard let illumination = solarInfo.moonIlluminationFraction else { return "questionmark.circle" }
        // This is simplified. Accurate symbols might need to know waxing/waning.
        if illumination < 0.03 { return "moonphase.new.moon" }
        if illumination < 0.24 { return "moonphase.waxing.crescent" }
        if illumination < 0.26 { return "moonphase.first.quarter" }
        if illumination < 0.49 { return "moonphase.waxing.gibbous" }
        if illumination < 0.51 { return "moonphase.full.moon" }
        if illumination < 0.74 { return "moonphase.waning.gibbous" }
        if illumination < 0.76 { return "moonphase.last.quarter" }
        if illumination <= 1.0 { return "moonphase.waning.crescent" } // before becoming new again
        return "moon.circle.fill" // Default
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Moon Insights")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 2)

            SolarDataRow(iconName: "moon.stars.fill", label: "Moonrise", value: format(solarInfo.moonrise))
            SolarDataRow(iconName: "moon.zzz.fill", label: "Moonset", value: format(solarInfo.moonset))
            SolarDataRow(iconName: moonPhaseSymbol, label: "Phase", value: solarInfo.moonPhaseName)
            if let illumination = solarInfo.moonIlluminationFraction {
                SolarDataRow(iconName: "sun.max.circle.fill", label: "Illumination", value: String(format: "%.0f%%", illumination * 100))
            } else {
                SolarDataRow(iconName: "sun.max.circle.fill", label: "Illumination", value: "N/A")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
