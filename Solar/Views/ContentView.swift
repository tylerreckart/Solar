//
//  ContentView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI
import CoreData

struct NavigationBar: View {
    var city: String
    var conditions: SkyCondition
    var showShareSheet: () -> Void
    @Binding var showingCitySheet: Bool
    @Binding var showingSettingsView: Bool
    @Binding var barColor: Color

    var body: some View {
        HStack(alignment: .center) {
            Button(action: {
                showShareSheet()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack {
                HStack(alignment: .center, spacing: 8) {
                    Text(city)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundColor(.white)
            .onTapGesture {
                showingCitySheet = true
            }
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
            
            
            Spacer()
            
            
            Button(action: {
                showingSettingsView = true
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 5)
        .background(self.barColor)
        .onChange(of: conditions) { oldConditions, newConditions in // Ensure correct onChange signature
            switch newConditions {
            case .sunrise:
                self.barColor = AppColors.sunriseGradientStart
            case .daylight:
                self.barColor = AppColors.daylightGradientStart
            case .sunset:
                self.barColor = AppColors.sunsetGradientStart
            case .night:
                self.barColor = AppColors.nightGradientStart
            }
        }
    }
}

// Extracted Main Content View for clarity
struct MainSolarView: View {
    @ObservedObject var viewModel: SunViewModel
    @EnvironmentObject var appSettings: AppSettings // Ensure AppSettings is available if needed by subviews
    
    // Bindings and States previously in ContentView that are relevant to MainSolarView
    @Binding var barColor: Color
    @Binding var showingCitySearchSheet: Bool
    @Binding var showingSettingsView: Bool
    @Binding var showShareSheet: Bool
    @Binding var activityItems: [Any]
    
    @Environment(\.managedObjectContext) private var viewContext // If CitySearchView needs it
    
    @State private var isPreparingShareData: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NavigationBar(
                    city: viewModel.solarInfo.city,
                    conditions: viewModel.currentSkyCondition,
                    showShareSheet: prepareAndShowShareSheet,
                    showingCitySheet: $showingCitySearchSheet,
                    showingSettingsView: $showingSettingsView,
                    barColor: $barColor
                )
                
                ScrollView {
                    VStack(spacing: 0) {
                        SolarGreetingView(solarInfo: viewModel.solarInfo, skyCondition: viewModel.currentSkyCondition)
                            .padding(.top, 40)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity)
                            .background(self.barColor)
                        
                        SunPathView(progress: viewModel.solarInfo.sunProgress, skyCondition: viewModel.currentSkyCondition)
                            .id(viewModel.solarInfo.city) // Re-render if city changes
                        
                        ZStack {
                            Color.black.frame(maxHeight: .infinity).edgesIgnoringSafeArea(.all)
                            
                            VStack(spacing: 25) {
                                ForEach(appSettings.dataSections.filter { $0.isVisible }.sorted(by: { $0.order < $1.order }), id: \.type) { sectionSetting in
                                    switch sectionSetting.type {
                                    case .solarDataList:
                                        SolarDataListView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                                            .padding(.horizontal)
                                    case .hourlyUVChart:
                                        if !viewModel.solarInfo.hourlyUVData.isEmpty {
                                            HourlyUVChartView(
                                                hourlyUVData: viewModel.solarInfo.hourlyUVData,
                                                timezoneIdentifier: viewModel.solarInfo.timezoneIdentifier
                                            )
                                            .padding(.horizontal)
                                        }
                                    case .airQuality:
                                        AirQualityView(solarInfo: viewModel.solarInfo)
                                            .padding(.horizontal)
                                    case .solarCountdown:
                                        SolarCountdownView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                                            .padding(.horizontal)
                                    case .goldenHour:
                                        GoldenHourView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                                            .padding(.horizontal)
                                    }
                                }
                                Spacer() // Pushes content up
                            }
                            .offset(y: -50) // Adjust for SunPathView overlap design
                        }
                    }
                }
                .background(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: barColor, location: 0.0),
                        .init(color: barColor, location: 0.5), // Extends barColor further down
                        .init(color: .black, location: 0.5),
                        .init(color: .black, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .clipped()
                .edgesIgnoringSafeArea(.bottom)
            }
            
            if isPreparingShareData {
                VStack {
                    ProgressView("Preparing Share...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .font(.caption)
                        .padding()
                        .background(.ultraThinMaterial) // Material background
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1)) // Slight dimming
                .edgesIgnoringSafeArea(.all)
            }
        }
        .navigationBarHidden(true)
        // .onAppear and .onReceive moved to the root ContentView's NavigationView container
        .sheet(isPresented: $showingCitySearchSheet) {
            CitySearchView(viewModel: viewModel).environment(\.managedObjectContext, self.viewContext)
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView(appSettings: appSettings) // appSettings is from @EnvironmentObject
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: activityItems)
        }
    }

    @MainActor
    private func prepareAndShowShareSheet() {
        // Ensure viewModel.solarInfo.city is valid and not a placeholder before preparing items
        guard !viewModel.solarInfo.city.isEmpty,
              viewModel.solarInfo.city != "Loading...",
              viewModel.solarInfo.city != "Select a City",
              viewModel.solarInfo.city != SolarInfo.placeholder().city // Check against actual placeholder value
        else {
            print("Share Sheet: City data not ready ('\(viewModel.solarInfo.city)'), aborting share.")
            // Optionally, you could set an alert to inform the user.
            // For now, we just prevent the share sheet from showing with bad data.
            return
        }
        
        withAnimation {
            isPreparingShareData = true
        }
        
        Task {
            var itemsToShare: [Any] = []
            let shareText = "Check out the solar conditions for \(viewModel.solarInfo.city)!"
            itemsToShare.append(shareText)
            
            if let appURL = URL(string: "https://apps.apple.com/app/id6745826724") {
                itemsToShare.append(appURL)
            }
            
            // Update the activityItems state
            self.activityItems = itemsToShare

            do {
                try await Task.sleep(for: .milliseconds(1000))
            } catch {
                print("Share Sheet: Task.sleep was cancelled.")
                isPreparingShareData = false // Ensure indicator is hidden on error/cancellation
                return
            }
            
            // Check if the task was cancelled during sleep
            if Task.isCancelled {
                print("Share Sheet: Task was cancelled after sleep.")
                isPreparingShareData = false
                return
            }
            
            withAnimation {
                isPreparingShareData = false
            }
            self.showShareSheet = true
            print("Share Sheet: Attempting to show with items: \(self.activityItems)")
        }
    }
}


struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = SunViewModel()
    @EnvironmentObject var appSettings: AppSettings // Inject AppSettings

    // States that were previously in ContentView, now passed to MainSolarView if needed by it or its sheets
    @State private var showingCitySearchSheet = false
    @State private var showingSettingsView = false
    @State private var showShareSheet = false
    @State private var activityItems: [Any] = []
    @State private var barColor: Color = AppColors.daylightGradientStart


    var body: some View {
        NavigationView {
            VStack { // Encapsulate switch in a VStack or Group if needed
                switch viewModel.dataLoadingState {
                case .idle:
                    ProgressView()
                    Text("Initializing...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .onAppear { // Trigger initial load if idle for too long (e.g., defensive)
                            if viewModel.solarInfo.city.isEmpty || viewModel.solarInfo.city == "Loading..." {
                                print("ContentView: ViewModel is idle, attempting to refresh solar data.")
                                viewModel.refreshSolarDataForCurrentCity()
                            }
                        }
                case .loading:
                    ProgressView()
                    Text("Fetching solar data...")
                        .font(.caption)
                        .foregroundColor(.gray)
                case .success:
                    MainSolarView(
                        viewModel: viewModel,
                        barColor: $barColor,
                        showingCitySearchSheet: $showingCitySearchSheet,
                        showingSettingsView: $showingSettingsView,
                        showShareSheet: $showShareSheet,
                        activityItems: $activityItems
                    )
                case .error(let message):
                    ErrorView(message: message) {
                        print("ContentView: Retry action tapped for error: \(message)")
                        viewModel.refreshSolarDataForCurrentCity()
                    }
                }
            }
            .navigationBarHidden(true) // Keep this on the VStack inside NavigationView
            .onAppear {
                // Initial data refresh trigger, especially if init didn't complete for some reason
                // Or if coming back to the view.
                print("ContentView: onAppear, refreshing solar data.")
                viewModel.refreshSolarDataForCurrentCity()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("ContentView: App will enter foreground, refreshing solar data.")
                viewModel.refreshSolarDataForCurrentCity()
            }
            .onChange(of: viewModel.currentSkyCondition) {
                print("MainSolarView: viewModel.currentSkyCondition changed to \(viewModel.currentSkyCondition). Updating barColor.")
                switch viewModel.currentSkyCondition {
                case .sunrise:
                    barColor = AppColors.sunriseGradientStart
                case .daylight:
                    barColor = AppColors.daylightGradientStart
                case .sunset:
                    barColor = AppColors.sunsetGradientStart
                case .night:
                    barColor = AppColors.nightGradientStart
                }
            }
        }
    }
}
