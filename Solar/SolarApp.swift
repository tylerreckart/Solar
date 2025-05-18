//
//  SolarApp.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

@main
struct SolarApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var appSettings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appSettings)
                .fontDesign(.rounded)
                .preferredColorScheme(.dark)
        }
    }
}
