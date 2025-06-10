//
//  ShareableView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI

struct ShareableView: View {
    let solarInfo: SolarInfo
    let skyCondition: SkyCondition
    let barColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // Solar Greeting View
            SolarGreetingView(solarInfo: solarInfo, skyCondition: skyCondition)
                .padding(.vertical, 20)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(barColor)

            // Sun Path View
            SunPathView(solarInfo: solarInfo, skyCondition: skyCondition)
                .frame(height: 250)
        }
        .background(Color.black)
    }
}
