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
                        HStack {
                            ZStack {
                                Rectangle().fill(AppColors.uvVeryHigh).frame(width: 32, height: 32).cornerRadius(10)
                                Image(systemName: "iphone.badge.location")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .symbolRenderingMode(.hierarchical)
                                    .padding(.top, 4)
                            }
                            Text("Use Current Lcoation")
                            Spacer()
                        }
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
                        HStack {
                            Text("Location Services Settings")
                            Spacer()
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    .padding(.top, 10)
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
                        
                        ForEach(appSettings.dataSections.indices, id: \.self) { index in
                            let sectionSetting = $appSettings.dataSections[index] // Get the binding for the current item
                            VStack {
                                HStack {
                                    ZStack {
                                        Rectangle().fill(sectionSetting.wrappedValue.type.defaultColor).frame(width: 32, height: 32).cornerRadius(10)
                                        Image(systemName: sectionSetting.wrappedValue.type.defaultSymbol)
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    Text(sectionSetting.wrappedValue.type.rawValue)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Toggle("", isOn: sectionSetting.isVisible) // Use the binding directly
                                        .labelsHidden()
                                        .tint(AppColors.primaryAccent)
                                }
                                // Conditionally show the Divider
                                if index < appSettings.dataSections.count - 1 {
                                    Divider()
                                }
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
                            HStack {
                                ZStack {
                                    Rectangle().fill(AppColors.primaryAccent).frame(width: 32, height: 32).cornerRadius(10)
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                Text("Enable All Notifications")
                                Spacer()
                            }
                        }
                        
                        if appSettings.notificationsEnabled {
                            Divider()
                            Toggle(isOn: $appSettings.sunriseAlert) {
                                HStack {
                                    ZStack {
                                        Rectangle().fill(AppColors.uvModerate).frame(width: 32, height: 32).cornerRadius(10)
                                        Image(systemName: "sunrise")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    Text("Sunrise Alerts")
                                    Spacer()
                                }
                            }
                            Divider()
                            Toggle(isOn: $appSettings.sunsetAlert) {
                                HStack {
                                    ZStack {
                                        Rectangle().fill(AppColors.sunsetGradientStart).frame(width: 32, height: 32).cornerRadius(10)
                                        Image(systemName: "sunset")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    Text("Sunset Alerts")
                                    Spacer()
                                }
                            }
                            Divider()
                            Toggle(isOn: $appSettings.highUVAlert) {
                                HStack {
                                    ZStack {
                                        Rectangle().fill(AppColors.uvVeryHigh).frame(width: 32, height: 32).cornerRadius(10)
                                        Image(systemName: "sun.max.trianglebadge.exclamationmark")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    Text("High UV Index Alerts")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Notification Settings")
                            Spacer()
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    .padding(.top, 10)
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
                            NavigationLink(destination: {
                                AboutView()
                            }) {
                                HStack {
                                    ZStack {
                                        Rectangle().fill(AppColors.uvVeryHigh).frame(width: 32, height: 32).cornerRadius(10)
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    Text("About")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                        }
                        Divider()
                        HStack {
                            ZStack {
                                Rectangle().fill(AppColors.uvHigh).frame(width: 32, height: 32).cornerRadius(10)
                                Image(systemName: "richtext.page.fill")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            Link("Terms of Service", destination: URL(string: "https://www.haptic.software/terms.html")!)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            ZStack {
                                Rectangle().fill(AppColors.uvModerate).frame(width: 32, height: 32).cornerRadius(10)
                                Image(systemName: "text.rectangle.page.fill")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            Link("Privacy Policy", destination: URL(string: "https://www.haptic.software/privacy.html")!)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        Divider()
                        HStack {
                            ZStack {
                                Rectangle().fill(AppColors.uvLow).frame(width: 32, height: 32).cornerRadius(10)
                                Image(systemName: "wifi")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            Link("APIs Used", destination: URL(string: "https://open-meteo.com")!)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    .padding(.bottom, 100)
                } header: {
                    HStack {
                        Text("About & Legal")
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
