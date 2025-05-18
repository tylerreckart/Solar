//
//  AppSettings.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import Foundation
import SwiftUI
import Combine

struct DataSectionSettings: Identifiable, Codable, Hashable {
    var id = UUID() // Unique identifier for ForEach loops and list manipulation
    var type: DataSectionType
    var isVisible: Bool
    var order: Int // Determines the display order on the main screen

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
    
    @Published var useCurrentLocation: Bool = true
    @Published var notificationsEnabled: Bool = true
    @Published var sunriseAlert: Bool = false
    @Published var sunsetAlert: Bool = false
    @Published var highUVAlert: Bool = false

    @Published var dataSections: [DataSectionSettings] {
        didSet {
            saveDataSectionsToUserDefaults()
        }
    }

    private let userDefaultsKey = "appDataSectionsConfiguration"

    init() {
        // Try to load saved settings
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedSections = try? JSONDecoder().decode([DataSectionSettings].self, from: savedData) {

            var currentSections = decodedSections
            var existingTypes = Set(currentSections.map { $0.type })
            var maxOrder = currentSections.map { $0.order }.max() ?? -1

            // Add any new section types not present in saved data (e.g., after an app update)
            for type in DataSectionType.allCases {
                if !existingTypes.contains(type) {
                    maxOrder += 1
                    currentSections.append(DataSectionSettings(type: type, isVisible: true, order: maxOrder))
                    existingTypes.insert(type)
                }
            }
            // Sort by order before assigning, then re-assign to ensure contiguous order
            self.dataSections = currentSections.sorted(by: { $0.order < $1.order })
            self.normalizeOrder() // Ensure order is contiguous after loading and adding new types

        } else {
            // Initialize with default settings if nothing is saved or decoding fails
            self.dataSections = DataSectionType.allCases.enumerated().map { index, type in
                DataSectionSettings(type: type, isVisible: true, order: index)
            }
        }
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
}
