//
//  SolarGreetingView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI

struct SolarGreetingView: View {
    let solarInfo: SolarInfo
    let skyCondition: SkyCondition // To potentially adjust greeting tone

    private var greetingMessage: String {
        let now = Date()

        // Upcoming events
        if let timeToSunrise = solarInfo.timeToSunrise, now < solarInfo.sunrise {
            if timeToSunrise == "Now" {
                 return "Rise and shine! Sunrise is happening now."
            }
            return "It's \(timeToSunrise) to sunrise."
        }
        if let timeToSolarNoon = solarInfo.timeToSolarNoon, now < solarInfo.solarNoon {
            if timeToSolarNoon == "Now" {
                return "Look up! It's solar noon."
            }
            return "\(timeToSolarNoon) until solar noon."
        }
        if let timeToSunset = solarInfo.timeToSunset, now < solarInfo.sunset {
            if timeToSunset == "Now" {
                return "Enjoy the view! Sunset is beginning."
            }
            return "\(timeToSunset) to sunset."
        }

        // Past events (if no upcoming events for the day)
        if let timeFromSunset = solarInfo.timeFromSunset, now >= solarInfo.sunset {
             // Check if it's deep into the night vs just after sunset
            let hoursSinceSunset = Calendar.current.dateComponents([.hour], from: solarInfo.sunset, to: now).hour ?? 0
            if hoursSinceSunset > 4 { // Arbitrary threshold for "night"
                return "Sunset was \(timeFromSunset)."
            }
            return "Sunset was \(timeFromSunset)."
        }
        if let timeFromSolarNoon = solarInfo.timeFromSolarNoon, now >= solarInfo.solarNoon {
            // This will likely be caught by "timeToSunset" if sunset hasn't occurred.
            // So, this implies it's after solar noon AND after sunset (or sunset data is missing).
            // Or, if it's daylight but past solar noon.
            if now < solarInfo.sunset { // Still daylight, but past noon
                 return "The afternoon is here! It's been \(timeFromSolarNoon) since solar noon."
            }
            // If after sunset as well, the timeFromSunset message is usually better.
            // This is a fallback.
            return "Solar noon was \(timeFromSolarNoon)."
        }
        if let timeFromSunrise = solarInfo.timeFromSunrise, now >= solarInfo.sunrise {
            // This implies it's after sunrise, but before solar noon (or noon data is missing).
             if now < solarInfo.solarNoon {
                return "Sunrise was \(timeFromSunrise)."
            }
            // Fallback if other conditions aren't met
            return "Sunrise was \(timeFromSunrise)."
        }
        
        // Generic fallback
        switch skyCondition {
            case .sunrise: return "Sunrise is approaching."
            case .daylight: return "Enjoy the daylight."
            case .sunset: return "Sunset is nearing."
            case .night: return "Good night!"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(greetingMessage)
                .font(.system(size: 18, weight: .bold))
                .padding(.vertical, 8)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .id(greetingMessage)
        }
        .padding(.horizontal)
    }
}
