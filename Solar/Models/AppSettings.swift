//
//  AppSettings.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import Foundation
import SwiftUI
import Combine
import WidgetKit

struct DataSectionSettings: Identifiable, Codable, Hashable {
    var id = UUID() // Unique identifier for ForEach loops and list manipulation
    var type: DataSectionType
    var isVisible: Bool
    var order: Int // Determines the display order on the main screen
    var symbol: String

    // Conformance to Hashable for use with .onMove in lists
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DataSectionSettings, rhs: DataSectionSettings) -> Bool {
        lhs.id == rhs.id
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var useCurrentLocation: Bool = true { // Add didSet observer
        didSet {
            UserDefaults.standard.set(useCurrentLocation, forKey: UserDefaultsKeys.useCurrentLocation) // Save to UserDefaults
            SharedDataManager.shared.useCurrentLocation = useCurrentLocation // Also save to shared storage for widgets
            
            // Refresh widgets when location setting changes
            print("🔄 AppSettings: useCurrentLocation changed to \(useCurrentLocation), refreshing widgets")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var notificationsEnabled: Bool = true
    @Published var sunriseAlert: Bool = true
    @Published var sunsetAlert: Bool = true
    @Published var highUVAlert: Bool = true

    @Published var dataSections: [DataSectionSettings] {
        didSet {
            saveDataSectionsToUserDefaults()
        }
    }

    private let userDefaultsKey = "appDataSectionsConfiguration"

    init() {
        // Load useCurrentLocation from UserDefaults, default to true if not found
        self.useCurrentLocation = UserDefaults.standard.object(forKey: UserDefaultsKeys.useCurrentLocation) as? Bool ?? true
        
        // Try to load saved settings for dataSections
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedSections = try? JSONDecoder().decode([DataSectionSettings].self, from: savedData) {

            var currentSections = decodedSections
            var existingTypes = Set(currentSections.map { $0.type })
            var maxOrder = currentSections.map { $0.order }.max() ?? -1

            // Add any new section types not present in saved data (e.g., after an app update)
            for type in DataSectionType.allCases {
                if !existingTypes.contains(type) {
                    maxOrder += 1
                    currentSections.append(DataSectionSettings(type: type, isVisible: true, order: maxOrder, symbol: ""))
                    existingTypes.insert(type)
                }
            }
            // Sort by order before assigning, then re-assign to ensure contiguous order
            self.dataSections = currentSections.sorted(by: { $0.order < $1.order })
            self.normalizeOrder() // Ensure order is contiguous after loading and adding new types

        } else {
            // Initialize with default settings if nothing is saved or decoding fails
            self.dataSections = DataSectionType.allCases.enumerated().map { index, type in
                DataSectionSettings(type: type, isVisible: true, order: index, symbol: "")
            }
        }
        
        // After all properties are initialized, sync useCurrentLocation to SharedDataManager
        SharedDataManager.shared.useCurrentLocation = self.useCurrentLocation
    }

    private func saveDataSectionsToUserDefaults() {
        if let encodedData = try? JSONEncoder().encode(dataSections) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }

    // Ensures 'order' is always a contiguous sequence starting from 0
    private func normalizeOrder() {
        for index in dataSections.indices {
            dataSections[index].order = index
        }
    }

    // Call this when sections are reordered in the SettingsView
    func moveSection(from source: IndexSet, to destination: Int) {
        dataSections.move(fromOffsets: source, toOffset: destination)
        normalizeOrder() // After moving, re-calculate and save the order
        // Note: saveDataSectionsToUserDefaults() is called by the @Published didSet
    }

    // Call this when a toggle for section visibility changes
    func toggleVisibility(for sectionType: DataSectionType) {
        if let index = dataSections.firstIndex(where: { $0.type == sectionType }) {
            dataSections[index].isVisible.toggle()
            // Note: saveDataSectionsToUserDefaults() is called by the @Published didSet
        }
    }
    
    // Debug function to check widget data sync
    func debugWidgetDataSync() {
        print("🔍 AppSettings: Debug Widget Data Sync")
        print("  - useCurrentLocation (AppSettings): \(useCurrentLocation)")
        SharedDataManager.shared.printDebugInfo()
        
        // Test widget location resolution
        if let location = SharedDataManager.shared.getWidgetLocation() {
            print("  - Widget would use: \(location.city) (\(location.latitude), \(location.longitude))")
        } else {
            print("  - Widget location resolution failed")
        }
    }
}
