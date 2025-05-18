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
            VStack {
                Section {
                    VStack {
                        VStack {
                            HStack {
                                Text("Enable or disable data sections on the main screen.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 5)
                                Spacer()
                            }
                            Divider()
                        }
                        
                        ForEach($appSettings.dataSections, id: \.type) { $sectionSetting in
                            VStack {
                                HStack {
                                    Text(sectionSetting.type.rawValue)
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Toggle("", isOn: $sectionSetting.isVisible)
                                        .labelsHidden()
                                        .tint(AppColors.primaryAccent)
                                }
                                Divider()
                            }
                        }
                        .onMove(perform: appSettings.moveSection)
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                } header: {
                    HStack {
                        Text("Customization")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.systemGray))
                            .textCase(nil)

                        Spacer()
                    }
                    .padding(.horizontal, 15)
                    .padding(.top)
                }
                .padding(.horizontal)

                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Link("Terms of Service", destination: URL(string: "https://www.example.com/terms")!)
                                .foregroundColor(AppColors.primaryAccent)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Link("Privacy Policy", destination: URL(string: "https://www.example.com/privacy")!)
                                .foregroundColor(AppColors.primaryAccent)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Link("API Usage & Acknowledgements", destination: URL(string: "https://open-meteo.com")!) // Link to Open-Meteo as an example
                                .foregroundColor(AppColors.primaryAccent)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                } header: {
                    HStack {
                        Text("Legal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.systemGray))
                            .textCase(nil)

                        Spacer()
                    }
                    .padding(.horizontal, 15)
                    .padding(.top)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 50)
            .edgesIgnoringSafeArea(.all)
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .background(.black)
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryAccent)
                }
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .tint(AppColors.primaryAccent)
    }
}

// Optional: Preview Provider for SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AppSettings for previewing
        SettingsView(appSettings: AppSettings())
    }
}
