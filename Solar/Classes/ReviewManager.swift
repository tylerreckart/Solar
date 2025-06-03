//
//  ReviewManager.swift
//  Solar
//
//  Created by Tyler Reckart on 6/3/25.
//

import Foundation
import StoreKit // For SKStoreReviewController
import UIKit    // For UIWindowScene

class ReviewManager {
    static let shared = ReviewManager()

    private let userDefaults = UserDefaults.standard

    private enum UserDefaultsKeys {
        static let appLaunchCount = "appLaunchCount"
        static let significantActionCount = "significantActionCount"
        static let lastReviewRequestDate = "lastReviewRequestDate"
        static let lastVersionPromptedForReview = "lastVersionPromptedForReview"
        static let firstLaunchDate = "firstLaunchDate" // Track first launch for time-based prompts
    }

    // Thresholds for prompting - adjust these as needed
    private let minLaunchesBeforePrompt = 5
    private let minSignificantActionsBeforePrompt = 3
    private let minDaysSinceFirstLaunchBeforePrompt = 7 // e.g., prompt after 1 week of use
    private let minDaysBetweenPrompts = 90 // Apple recommends not prompting too frequently

    private init() {
        // Record the first launch date if it's not already set
        if userDefaults.object(forKey: UserDefaultsKeys.firstLaunchDate) == nil {
            userDefaults.set(Date(), forKey: UserDefaultsKeys.firstLaunchDate)
        }
    }

    // Call this from your AppDelegate or SolarApp struct on launch
    func incrementAppLaunchCount() {
        let currentCount = userDefaults.integer(forKey: UserDefaultsKeys.appLaunchCount)
        userDefaults.set(currentCount + 1, forKey: UserDefaultsKeys.appLaunchCount)
        print("🚀 ReviewManager: App launch count: \(currentCount + 1)")
    }

    // Call this after a positive user interaction (e.g., successful data load, city search)
    func logSignificantAction() {
        let currentCount = userDefaults.integer(forKey: UserDefaultsKeys.significantActionCount)
        userDefaults.set(currentCount + 1, forKey: UserDefaultsKeys.significantActionCount)
        print("👍 ReviewManager: Significant action count: \(currentCount + 1)")

        // After logging a significant action, check if we should prompt
        requestReviewIfAppropriate()
    }
    
    // Call this when the app becomes active, perhaps after a slight delay
    // to ensure the main UI is up and the user isn't immediately interrupted.
    func requestReviewOnAppActive() {
        // Check time-based and launch-based conditions first
        let launchCount = userDefaults.integer(forKey: UserDefaultsKeys.appLaunchCount)
        guard launchCount >= minLaunchesBeforePrompt else {
            print("🌟 ReviewManager: Not prompting (launch count \(launchCount) < \(minLaunchesBeforePrompt))")
            return
        }

        if let firstLaunch = userDefaults.object(forKey: UserDefaultsKeys.firstLaunchDate) as? Date {
            let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
            guard daysSinceFirstLaunch >= minDaysSinceFirstLaunchBeforePrompt else {
                print("🌟 ReviewManager: Not prompting (days since first launch \(daysSinceFirstLaunch) < \(minDaysSinceFirstLaunchBeforePrompt))")
                return
            }
        }
        
        requestReviewIfAppropriate()
    }


    func requestReviewIfAppropriate() {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let lastPromptedVersion = userDefaults.string(forKey: UserDefaultsKeys.lastVersionPromptedForReview)
        
        // Condition 1: Has this version already been prompted? (Optional, Apple handles some of this)
        // You might want to prompt once per major/minor version update if desired.
        // For now, we'll rely more on time since last prompt and action counts.
        // if lastPromptedVersion == currentVersion {
        //     print("🌟 ReviewManager: Already prompted for review in version \(currentVersion).")
        //     return
        // }

        // Condition 2: Time since last prompt
        if let lastRequestDate = userDefaults.object(forKey: UserDefaultsKeys.lastReviewRequestDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0
            guard daysSinceLastPrompt >= minDaysBetweenPrompts else {
                print("🌟 ReviewManager: Not prompting (last prompt was \(daysSinceLastPrompt) days ago, less than \(minDaysBetweenPrompts) days).")
                return
            }
        }
        
        // Condition 3: App launch count
        let launchCount = userDefaults.integer(forKey: UserDefaultsKeys.appLaunchCount)
        guard launchCount >= minLaunchesBeforePrompt else {
            print("🌟 ReviewManager: Not prompting (launch count \(launchCount) < \(minLaunchesBeforePrompt)).")
            return
        }

        // Condition 4: Significant action count
        let actionCount = userDefaults.integer(forKey: UserDefaultsKeys.significantActionCount)
        guard actionCount >= minSignificantActionsBeforePrompt else {
            print("🌟 ReviewManager: Not prompting (significant actions \(actionCount) < \(minSignificantActionsBeforePrompt)).")
            return
        }
        
        // Condition 5: Time since first launch (if not prompted before for this version or at all)
        if lastPromptedVersion == nil || lastPromptedVersion != currentVersion { // More likely to prompt if new version or never prompted
            if let firstLaunch = userDefaults.object(forKey: UserDefaultsKeys.firstLaunchDate) as? Date {
                let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
                guard daysSinceFirstLaunch >= minDaysSinceFirstLaunchBeforePrompt else {
                    print("🌟 ReviewManager: Not prompting (days since first launch \(daysSinceFirstLaunch) < \(minDaysSinceFirstLaunchBeforePrompt) for initial prompt).")
                    return
                }
            }
        }


        print("🌟 ReviewManager: Conditions met. Requesting review.")
        
        // Find the active window scene
        DispatchQueue.main.async { // Ensure UI work is on the main thread
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                print("❌ ReviewManager: Could not find active window scene to request review.")
                return
            }
            SKStoreReviewController.requestReview(in: windowScene)
            
            // Update UserDefaults after requesting
            self.userDefaults.set(Date(), forKey: UserDefaultsKeys.lastReviewRequestDate)
            self.userDefaults.set(currentVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReview)
            // Optionally reset significant action count after a prompt, so it builds up again.
            // self.userDefaults.set(0, forKey: UserDefaultsKeys.significantActionCount)
            print("🌟 ReviewManager: Review requested. Last prompt date and version updated.")
        }
    }

    // For testing purposes, you might want a way to reset these values.
    func resetReviewPromptCounters() {
        userDefaults.removeObject(forKey: UserDefaultsKeys.appLaunchCount)
        userDefaults.removeObject(forKey: UserDefaultsKeys.significantActionCount)
        userDefaults.removeObject(forKey: UserDefaultsKeys.lastReviewRequestDate)
        userDefaults.removeObject(forKey: UserDefaultsKeys.lastVersionPromptedForReview)
        userDefaults.removeObject(forKey: UserDefaultsKeys.firstLaunchDate) // Also reset first launch for full test
        print("⚠️ ReviewManager: Counters reset for testing.")
    }
}
