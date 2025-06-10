//
//  Solar_WidgetsBundle.swift
//  Solar-Widgets
//
//  Created by Tyler Reckart on 6/10/25.
//

import WidgetKit
import SwiftUI

@main
struct Solar_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        SolarPathWidget()
        AirQualityWidget()
        UVIndexWidget()
        // Control Widgets and Live Activities require iOS 18.0+
        // Will be added in future update when deployment target is raised
    }
}
