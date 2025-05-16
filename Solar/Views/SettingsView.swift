//
//  SettingsView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Customize Data Sections").font(.subheadline)) {
                    Text("Enable or disable sections and drag them to change their order on the main screen.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)

                    ForEach($appSettings.dataSections, id: \.type) { $sectionSetting in
                        HStack {
                            Text(sectionSetting.type.rawValue) // Display name from enum
                            Spacer()
                            Toggle("", isOn: $sectionSetting.isVisible)
                                .labelsHidden() // Hides the default "Toggle" label
                                .tint(AppColors.primaryAccent)
                        }
                    }
                    .onMove(perform: appSettings.moveSection)
                }

                Section(header: Text("About & Legal").font(.subheadline)) {
                    Link("Terms of Service", destination: URL(string: "https://www.example.com/terms")!)
                        .foregroundColor(AppColors.primaryAccent)
                    Link("Privacy Policy", destination: URL(string: "https://www.example.com/privacy")!)
                        .foregroundColor(AppColors.primaryAccent)
                    Link("API Usage & Acknowledgements", destination: URL(string: "https://open-meteo.com")!) // Link to Open-Meteo as an example
                        .foregroundColor(AppColors.primaryAccent)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton() // Enables list reordering functionality
                        .foregroundColor(AppColors.primaryAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryAccent)
                }
            }
        }
        .tint(AppColors.primaryAccent) // Sets the accent color for the NavigationView
    }
}

// Optional: Preview Provider for SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AppSettings for previewing
        SettingsView(appSettings: AppSettings())
    }
}
