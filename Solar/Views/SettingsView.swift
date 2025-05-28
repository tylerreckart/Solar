//
//  SettingsView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/16/25.
//

import SwiftUI
import UserNotifications
import MessageUI

// FeedbackHelper to generate mail details
struct FeedbackHelper {
    static func getMailComposeDetails() -> (recipient: String, subject: String, body: String)? {
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let recipientEmail = "support@haptic.software" // Your support email
        let subject = "Solar App Feedback (v\(appVersionString))"
        let body = """
        Please provide your feedback, bug reports, or feature requests below.
        
        ----------------------------------
        App Version: \(appVersionString) (Build \(appBuildString))
        iOS Version: \(iosVersion)
        Device: \(deviceModel)
        ----------------------------------
        
        My Feedback:
        
        """
        return (recipientEmail, subject, body)
    }
}

// UIViewControllerRepresentable for MFMailComposeViewController
struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss // To dismiss the sheet

    // Static details to avoid re-computation if not needed
    static var mailDetails = FeedbackHelper.getMailComposeDetails()

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool // To control the presentation from the parent

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            // Dismiss the mail compose view controller
            // The isPresented binding will handle dismissing the SwiftUI sheet
            isPresented = false
            
            if let error = error {
                print("Mail compose error: \(error.localizedDescription)")
            } else {
                print("Mail compose finished with result: \(result.rawValue)")
            }
        }
    }

    @Binding var isPresented: Bool // Binding to control the sheet presentation

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mc = MFMailComposeViewController()
        mc.mailComposeDelegate = context.coordinator
        if let details = MailComposeView.mailDetails {
            mc.setToRecipients([details.recipient])
            mc.setSubject(details.subject)
            mc.setMessageBody(details.body, isHTML: false)
        }
        return mc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No update needed
    }
}


struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismissView // Renamed to avoid conflict
    @State private var actualNotificationStatus: UNAuthorizationStatus = .notDetermined
    
    // States for in-app mail composer
    @State private var showingMailComposeSheet = false // Controls the .sheet presentation
    @State private var mailAlertMessage: String? = nil
    @State private var showMailUnavailableAlert = false


    var body: some View {
        NavigationView {
            ScrollView {
                // --- LOCATION SECTION ---
                Section {
                    Toggle(isOn: $appSettings.useCurrentLocation) {
                        HStack {
                            ZStack {
                                Rectangle().fill(AppColors.uvVeryHigh).frame(width: 32, height: 32).cornerRadius(10)
                                Image(systemName: "location.fill")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .symbolRenderingMode(.hierarchical)
                            }
                            Text("Use Current Location")
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
                            .padding(.horizontal)
                    }
                    
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Location Services Settings")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.gray)
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
                    .padding(.horizontal, 25)
                    .padding(.top)
                }
                .padding(.horizontal)
                
                // --- CUSTOMIZATION SECTION ---
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Enable or disable data sections on the main screen.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.bottom, 5)
                            Spacer()
                        }
                        .padding([.top, .horizontal])

                        ForEach(appSettings.dataSections.indices, id: \.self) { index in
                            let sectionSetting = $appSettings.dataSections[index]
                            
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
                                Toggle("", isOn: sectionSetting.isVisible)
                                    .labelsHidden()
                                    .tint(AppColors.primaryAccent)
                            }
                            .padding()

                            if index < appSettings.dataSections.count - 1 {
                                Divider()
                                    .background(Color.gray.opacity(0.2))
                                    .padding(.leading)
                            }
                        }
                        .onMove(perform: appSettings.moveSection)
                        
                    }
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
                    .padding(.horizontal, 25)
                    .padding(.top)
                }
                .padding(.horizontal)
                
                // --- NOTIFICATIONS SECTION ---
                Section {
                    VStack(alignment: .leading) {
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
                        .disabled(actualNotificationStatus == .denied)

                        if appSettings.notificationsEnabled && actualNotificationStatus == .denied {
                            Text("Notifications are disabled in your iPhone's Settings for Solar. Please enable them there to receive alerts.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 5)
                        }
                        
                        if appSettings.notificationsEnabled && actualNotificationStatus != .denied {
                            Divider().padding(.vertical, 5)
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
                            Divider().padding(.vertical, 5)
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
                            Divider().padding(.vertical, 5)
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
                            Text("Notification System Settings")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(AppColors.ui)
                    .cornerRadius(16)
                    .padding(.top, 10)

                    Text("You can manage detailed notification permissions and sounds in your device's Settings app.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                } header: {
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.systemGray))
                            .textCase(nil)
                        Spacer()
                    }
                    .padding(.horizontal, 25)
                    .padding(.top)
                }
                .padding(.horizontal)
                .onAppear {
                    NotificationScheduler.shared.getNotificationAuthorizationStatus { status in
                        self.actualNotificationStatus = status
                    }
                }

                // --- ABOUT & LEGAL SECTION ---
                Section {
                    VStack(alignment: .leading) {
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                ZStack {
                                    Rectangle().fill(AppColors.uvVeryHigh).frame(width: 32, height: 32).cornerRadius(10)
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                Text("About Solar")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.forward.square").foregroundColor(.gray)
                            }
                        }
                        Divider().padding(.vertical, 5)

                        // Updated Send Feedback Button
                        Button(action: {
                            if MFMailComposeViewController.canSendMail() {
                                self.showingMailComposeSheet = true // Trigger the sheet
                            } else {
                                self.mailAlertMessage = "Your device is not configured to send email. Please set up an email account in the Mail app."
                                self.showMailUnavailableAlert = true
                                print("Cannot send mail: Mail services are not available.")
                            }
                        }) {
                            HStack {
                                ZStack {
                                    Rectangle().fill(AppColors.daylightGradientStart).frame(width: 32, height: 32).cornerRadius(10)
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                Text("Send Feedback")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.forward.square").foregroundColor(.gray) // Indicate action
                            }
                        }
                        .sheet(isPresented: $showingMailComposeSheet) {
                            // Pass the binding to MailComposeView
                            MailComposeView(isPresented: $showingMailComposeSheet)
                                .ignoresSafeArea() // Allow mail composer to use full screen
                        }
                        .alert("Mail Unavailable", isPresented: $showMailUnavailableAlert) { // Changed alert title
                            Button("OK") { }
                        } message: {
                            Text(mailAlertMessage ?? "Please ensure your device is configured to send email.")
                        }


                        Divider().padding(.vertical, 5)
                        
                        Link(destination: URL(string: "https://www.haptic.software/terms.html")!) {
                             HStack {
                                ZStack {
                                    Rectangle().fill(AppColors.uvHigh).frame(width: 32, height: 32).cornerRadius(10)
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                Text("Terms of Service")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app").foregroundColor(.gray)
                            }
                        }
                        Divider().padding(.vertical, 5)
                        
                         Link(destination: URL(string: "https://www.haptic.software/privacy.html")!) {
                            HStack {
                                ZStack {
                                    Rectangle().fill(AppColors.uvModerate).frame(width: 32, height: 32).cornerRadius(10)
                                    Image(systemName: "lock.doc.fill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                Text("Privacy Policy")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app").foregroundColor(.gray)
                            }
                        }
                        Divider().padding(.vertical, 5)
                        
                        Link(destination: URL(string: "https://open-meteo.com")!) {
                            HStack {
                                ZStack {
                                    Rectangle().fill(AppColors.uvLow).frame(width: 32, height: 32).cornerRadius(10)
                                    Image(systemName: "cloud.sun.fill")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                Text("API Usage Acknowledgement")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app").foregroundColor(.gray)
                            }
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
                    .padding(.horizontal, 25)
                    .padding(.top)
                }
                .padding(.horizontal)

            }
            .padding(.top, 1)
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismissView() // Use the renamed dismiss action
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appSettings: AppSettings.shared)
            .preferredColorScheme(.dark)
    }
}
