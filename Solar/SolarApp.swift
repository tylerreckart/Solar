//
//  SolarApp.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI
import UserNotifications // Import UserNotifications

@main
struct SolarApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var appSettings = AppSettings.shared
    
    init() {
        // Initial request for notification permission
        requestNotificationPermissionAndUpdateSettings()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appSettings)
                .fontDesign(.rounded)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Re-check permissions and update settings when app enters foreground
                    print("App entered foreground, checking notification permissions.")
                    requestNotificationPermissionAndUpdateSettings()
                }
        }
    }

    // Helper function to request notification permission and update AppSettings
    private func requestNotificationPermissionAndUpdateSettings() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    print("Notification permission previously granted: \(settings.authorizationStatus).")

                case .denied:
                    print("Notification permission denied by user.")
                    if self.appSettings.notificationsEnabled {
                        print("System permission denied, forcing AppSettings.notificationsEnabled to false.")
                        self.appSettings.notificationsEnabled = false
                    }
                case .notDetermined:
                    print("Notification permission not determined. Requesting authorization...")
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            if granted {
                                print("Notification permission granted by user.")
                            } else {
                                print("Notification permission denied by user during request.")
                                if self.appSettings.notificationsEnabled {
                                    print("Forcing AppSettings.notificationsEnabled to false after explicit denial.")
                                    self.appSettings.notificationsEnabled = false
                                }
                            }
                            if let error = error {
                                print("Notification permission request error: \(error.localizedDescription)")
                            }
                            // After request, trigger a notification update in ViewModel if needed
                            // This might be handled by the AppSettings publisher in SunViewModel
                        }
                    }
                @unknown default:
                    print("Unknown notification authorization status.")
                    if self.appSettings.notificationsEnabled {
                        // self.appSettings.notificationsEnabled = false // Be cautious with unknown state
                        print("Unknown notification status, AppSettings.notificationsEnabled remains \(self.appSettings.notificationsEnabled).")
                    }
                }
            }
        }
    }
}
