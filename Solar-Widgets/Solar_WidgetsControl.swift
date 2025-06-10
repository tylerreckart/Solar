//
//  Solar_WidgetsControl.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct Solar_WidgetsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "Solar_WidgetsControl",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value,
                action: StartTimerIntent()
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

@available(iOSApplicationExtension 18.0, *)
extension Solar_WidgetsControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool {
            false
        }

        func currentValue() async throws -> Bool {
            let isRunning = true // Check if the timer is running
            return isRunning
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer is running")
    var value: Bool

    func perform() async throws -> some IntentResult {
        // Start / stop the timer based on `value`.
        return .result()
    }
}
