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
        .onChange(of: conditions) {
            switch conditions {
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

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var viewModel = SunViewModel()
    @State private var showingCitySearchSheet = false
    @State private var showingSettingsView = false
    @State private var showShareSheet = false
    @State private var activityItems: [Any] = []
    @State private var barColor: Color = AppColors.daylightGradientStart

    var body: some View {
        NavigationView {
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
                .navigationBarHidden(true)
                .onAppear {
                    viewModel.refreshSolarDataForCurrentCity()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    viewModel.refreshSolarDataForCurrentCity()
                }
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
            .fontDesign(.rounded)
        }
    }

    @ViewBuilder
    private func NavBar() -> some View {
        HStack(alignment: .center) {
            Button(action: {
                prepareAndShowShareSheet()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack {
                HStack(alignment: .center, spacing: 8) {
                    Text(viewModel.solarInfo.city)
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
                showingCitySearchSheet = true
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
    }
    
    @MainActor
    private func prepareAndShowShareSheet() {
        var itemsToShare: [Any] = []

        // 5. Prepare activity items with the generated image
        let shareText = "Check out the solar conditions for \(viewModel.solarInfo.city)!"
        itemsToShare.append(shareText)
        
         if let appURL = URL(string: "https://apps.apple.com/6745826724") {
             itemsToShare.append(appURL)
         }

        self.activityItems = itemsToShare
        self.showShareSheet = true
    }
}

//#Preview {
//    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//}
