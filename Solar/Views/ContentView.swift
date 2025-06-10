// Solar/Views/ContentView.swift

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
        .onChange(of: conditions) { oldConditions, newConditions in
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

struct MainSolarView: View {
    @ObservedObject var viewModel: SunViewModel
    @EnvironmentObject var appSettings: AppSettings
    
    @Binding var barColor: Color
    @Binding var showingCitySearchSheet: Bool
    @Binding var showingSettingsView: Bool
    @Binding var showShareSheet: Bool
    @Binding var activityItems: [Any]
    
    @Environment(\.managedObjectContext) private var viewContext
    
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
                        
                        SunPathView(solarInfo: viewModel.solarInfo, skyCondition: viewModel.currentSkyCondition)
                            .id(viewModel.solarInfo.city)
                        
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
                                Spacer()
                            }
                            .offset(y: -50)
                        }
                    }
                }
                .background(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: barColor, location: 0.0),
                        .init(color: barColor, location: 0.5),
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
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
                .edgesIgnoringSafeArea(.all)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCitySearchSheet) {
            CitySearchView(viewModel: viewModel).environment(\.managedObjectContext, self.viewContext)
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView(appSettings: appSettings)
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: activityItems)
        }
    }

    @MainActor
    private func prepareAndShowShareSheet() {
        guard !viewModel.solarInfo.city.isEmpty,
              viewModel.solarInfo.city != "Loading...",
              viewModel.solarInfo.city != "Select a City",
              viewModel.solarInfo.city != SolarInfo.placeholder().city
        else {
            print("Share Sheet: City data not ready ('\(viewModel.solarInfo.city)'), aborting share.")
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
            
            self.activityItems = itemsToShare

            do {
                try await Task.sleep(for: .milliseconds(1000))
            } catch {
                print("Share Sheet: Task.sleep was cancelled.")
                isPreparingShareData = false
                return
            }
            
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
    @EnvironmentObject var appSettings: AppSettings

    @State private var showingCitySearchSheet = false
    @State private var showingSettingsView = false
    @State private var showShareSheet = false
    @State private var activityItems: [Any] = []
    @State private var barColor: Color = AppColors.daylightGradientStart


    var body: some View {
        NavigationView {
            VStack {
                switch viewModel.dataLoadingState {
                case .idle:
                    ProgressView()
                    Text("Initializing...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        // Removed the onAppear block that was eagerly fetching data.
                        // Initial data loading is now handled in SunViewModel.init()
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
                    if message.contains("Location access was denied") || message.contains("Location access is restricted") || message.contains("Location permission status: Not Determined") {
                        ErrorView(message: message) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            viewModel.refreshSolarDataForCurrentCity()
                        }
                    } else if message.contains("Please search for a city.") || message.contains("No coordinates found for") || message.contains("No cities found matching") {
                        ErrorView(message: message) {
                            showingCitySearchSheet = true
                        }
                    } else {
                        ErrorView(message: message) {
                            print("ContentView: Generic retry action tapped for error: \(message)")
                            viewModel.refreshSolarDataForCurrentCity()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Keep this onAppear for initial setup that might be missed by init if view hierarchy is complex,
                // but no longer triggers a data fetch if viewModel is already handling it.
                // It ensures the ViewModel is observed and can begin its lifecycle properly.
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("ContentView: App will enter foreground, refreshing solar data.")
                viewModel.refreshSolarDataForCurrentCity() // Keep this for foreground refresh.
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
            .onChange(of: viewModel.shouldDismissActiveSheets) { dismiss in
                if dismiss {
                    withAnimation {
                        showingCitySearchSheet = false
                        showingSettingsView = false
                        showShareSheet = false
                    }
                    viewModel.shouldDismissActiveSheets = false
                    print("ContentView: Dismissed active sheets due to data refresh.")
                }
            }
        }
    }
}
