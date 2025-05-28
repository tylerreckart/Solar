//
//  NotificationScheduler.swift
//  Solar
//
//  Created by Tyler Reckart on 5/19/25.
//

import UserNotifications
import UIKit

class NotificationScheduler {

    static let shared = NotificationScheduler()

    private init() {}

    func scheduleNotification(identifier: String, title: String, body: String, date: Date, repeats: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Ensure the date is in the future
        guard date > Date() else {
            // Enhanced logging for skipped past-date notifications
            print("🗓️ Notification \(identifier) skipped: Schedule date \(date) is in the past. Current time: \(Date()).")
            return
        }

        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: repeats)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification \(identifier): \(error.localizedDescription)")
            } else {
                print("Successfully scheduled notification: \(identifier) for \(date)")
            }
        }
    }

    func scheduleUVNotification(identifier: String, title: String, body: String, date: Date, uvIndex: Int, threshold: Int = 6) {
        // Only schedule if UV index is high and date is in future
        guard uvIndex >= threshold else {
            print("☀️ UV Notification \(identifier) skipped: UV Index (\(uvIndex)) not >= threshold (\(threshold)).")
            return
        }
        guard date > Date() else {
            print("🗓️ UV Notification \(identifier) skipped: Schedule date \(date) is in the past. Current time: \(Date()).")
            return
        }
        scheduleNotification(identifier: identifier, title: title, body: body, date: date)
    }


    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled notification: \(identifier)")
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("Cancelled all pending notifications.")
    }
    
    // Helper to check current notification authorization status
    func getNotificationAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
}
