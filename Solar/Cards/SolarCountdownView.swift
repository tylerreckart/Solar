//
//  SolarCountdownView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/15/25.
//

import SwiftUI

struct SolarCountdownView: View {
    let solarInfo: SolarInfo
    let viewModel: SunViewModel // For formatting general times if needed, though SolarInfo handles countdowns

    // Helper to decide what to show for event times
    private func displayTime(for eventTime: String?, eventNameIfPast: String, eventNameIfUpcoming: String, timeValue: String?) -> (label: String, value: String)? {
        guard let timeVal = timeValue else { // Event is past or not applicable for "to"
            if eventNameIfPast == "Sunrise" && solarInfo.timeFromSunrise != nil {
                 return ("Sunrise was:", solarInfo.timeFromSunrise!)
            } else if eventNameIfPast == "Sunset" && solarInfo.timeFromSunset != nil {
                 return ("Sunset was:", solarInfo.timeFromSunset!)
            }
            return nil // Don't display if irrelevant
        }
        return (eventNameIfUpcoming, timeVal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Solar Timings")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 2)

            // Sunrise
            if let sunriseDisplay = displayTime(for: solarInfo.timeToSunrise, eventNameIfPast: "Sunrise", eventNameIfUpcoming: "Time to Sunrise:", timeValue: solarInfo.timeToSunrise ?? solarInfo.timeFromSunrise) {
                 SolarDataRow(iconName: "sunrise.fill", label: sunriseDisplay.label, value: sunriseDisplay.value)
            }
            
            // Solar Noon
            if let noonDisplay = displayTime(for: solarInfo.timeToSolarNoon, eventNameIfPast: "Solar Noon", eventNameIfUpcoming: "Time to Solar Noon:", timeValue: solarInfo.timeToSolarNoon) {
                SolarDataRow(iconName: "sun.max.fill", label: noonDisplay.label, value: noonDisplay.value)
            } else if Date() > solarInfo.solarNoon { // If past noon, show time since noon
                 let timeSinceNoon = solarInfo.formatTimeDifference(from: solarInfo.solarNoon, to: Date(), futurePrefix: "", pastSuffix: "ago", defaultString: "", isDuration: true)
                 if !timeSinceNoon.isEmpty {
                    SolarDataRow(iconName: "sun.max.fill", label: "Solar Noon was:", value: timeSinceNoon)
                 }
            }

            // Sunset
            if let sunsetDisplay = displayTime(for: solarInfo.timeToSunset, eventNameIfPast: "Sunset", eventNameIfUpcoming: "Time to Sunset:", timeValue: solarInfo.timeToSunset ?? solarInfo.timeFromSunset) {
                 SolarDataRow(iconName: "sunset.fill", label: sunsetDisplay.label, value: sunsetDisplay.value)
            }

            // Optionally, time to Civil Twilight End (evening)
            if let civilEnd = solarInfo.civilTwilightEnd, Date() < civilEnd {
                let timeToCivilEnd = solarInfo.formatTimeDifference(from: Date(), to: civilEnd, futurePrefix: "", pastSuffix: "ago", defaultString: "N/A")
                 SolarDataRow(iconName: "sun.haze.fill", label: "End of Civil Twilight:", value: timeToCivilEnd)
            }


        }
        .padding()
        .foregroundColor(.white)
        .background(AppColors.ui)
        .cornerRadius(16)
    }
}
