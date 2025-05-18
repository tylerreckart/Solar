//
//  SettingsView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI

struct FeedbackHelper {
    static func getFeedbackEmailUrl() -> URL? {
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let recipientEmail = "support@haptic.software"
        let subject = "Solar App Feedback (v\(appVersionString))"
        let body = """
        Please provide your feedback, bug reports, or feature requests below.
        
        ----------------------------------
        App Version: \(appVersionString) (\(appBuildString))
        iOS Version: \(iosVersion)
        Device: \(deviceModel)
        ----------------------------------
        
        My Feedback:
        
        """
        
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)),
            URLQueryItem(name: "body", value: body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        ]
        
        return components.url
    }
}

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Section {
                    Toggle(isOn: $appSettings.useCurrentLocation) {
                        Label("Use Current Location", systemImage: "location.fill")
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    
                    if !appSettings.useCurrentLocation {
                        Text("The app will use the last manually searched location. To set a new default, please perform a new city search from the main screen.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Button to open Location Services settings in iOS Settings
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Location Services Settings", systemImage: "location.circle")
                    }
                } header: {
                    HStack {
                        Text("Location")
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
                    VStack {
                        Toggle(isOn: $appSettings.notificationsEnabled) {
                            Label("Enable All Notifications", systemImage: "bell.badge")
                        }
                        
                        if appSettings.notificationsEnabled {
                            Toggle(isOn: $appSettings.sunriseAlert) {
                                Label("Sunrise Alerts", systemImage: "sunrise")
                            }
                            Toggle(isOn: $appSettings.sunsetAlert) {
                                Label("Sunset Alerts", systemImage: "sunset")
                            }
                            Toggle(isOn: $appSettings.highUVAlert) {
                                Label("High UV Index Alerts", systemImage: "sun.max.trianglebadge.exclamationmark")
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    
                    // Button to open app-specific notification settings in iOS Settings
                    Button {
//                        openAppSettingsNotificationSettings()
                    } label: {
                        Label("Notification Settings", systemImage: "gearshape")
                    }
                    Text("You can manage detailed notification permissions and sounds in your device's Settings app.")
                        .font(.caption)
                        .foregroundColor(.gray)
                } header: {
                    HStack {
                        Text("Notifications")
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
                            Link("Terms of Service", destination: URL(string: "https://www.haptic.software/terms.html")!)
                                .foregroundColor(AppColors.primaryAccent)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            Link("Privacy Policy", destination: URL(string: "https://www.haptic.software/privacy.html")!)
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
                    .padding(.bottom, 100)
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
