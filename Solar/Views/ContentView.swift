//
//  ContentView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = SunViewModel()
    @State private var showingCitySearchSheet = false
    @State private var barColor: Color = AppColors.sunriseGradientStart

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Color(barColor)
                        .frame(maxHeight: 200)
                    Spacer()
                }

                VStack(spacing: 0) {
                    customTopBar()
                        .edgesIgnoringSafeArea(.all)
                        .padding(.horizontal)
                        .padding(.top, 10) // Adjust for notch or status bar
                        .padding(.bottom, 5)
                        .background(self.barColor)
                        .onChange(of: viewModel.solarInfo) {
                            switch viewModel.currentSkyCondition {
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

                    ScrollView {
                        VStack(spacing: 0) { // Increased spacing between major elements
                            if !viewModel.dataLoadingState_isLoading() {
                                SolarGreetingView(solarInfo: viewModel.solarInfo, skyCondition: viewModel.currentSkyCondition)
                                        .padding(.top, 40)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity)
                                        .background(self.barColor)
                                
                                
                                SunPathView(progress: viewModel.solarInfo.sunProgress, skyCondition: viewModel.currentSkyCondition)
                                    .id(viewModel.solarInfo.city)
                                
                                VStack(spacing: 25) {
                                    SolarDataListView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                                        .padding(.horizontal)
                                        .opacity(viewModel.dataLoadingState_isLoading() ? 0.5 : 1.0)
                                        .overlay {
                                            if viewModel.dataLoadingState_isLoading() {
                                                ProgressView()
                                                    .scaleEffect(1.5)
                                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryAccent))
                                            }
                                        }
                                    
                                    if !viewModel.solarInfo.hourlyUVData.isEmpty {
                                        HourlyUVChartView(
                                            hourlyUVData: viewModel.solarInfo.hourlyUVData,
                                            timezoneIdentifier: viewModel.solarInfo.timezoneIdentifier
                                        )
                                        .padding(.horizontal)
                                    }
                                    
                                    AirQualityView(solarInfo: viewModel.solarInfo)
                                        .padding(.horizontal)
                                    
                                    SolarCountdownView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                                        .padding(.horizontal)
                                    
                                    GoldenHourView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                                        .padding(.horizontal)
                                }
                                .offset(y: -50)
                            }
                            Spacer()
                        }
                    }
                    .background(.black)
                }
                
                // Error Display Area
//                if case .error(let message) = viewModel.dataLoadingState {
//                    ErrorView(message: message, retryAction: {
//                        // Determine appropriate retry action
//                        if message.lowercased().contains("location") {
//                             viewModel.requestSolarDataForCurrentLocation()
//                        } else {
//                            viewModel.refreshSolarDataForCurrentCity()
//                        }
//                    })
//                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCitySearchSheet) {
                CitySearchView(viewModel: viewModel)
                    .environment(\.managedObjectContext, self.viewContext)
                    // Use new presentation detents if targeting iOS 16+
                    // .presentationDetents([.medium, .large])
            }
            .onAppear {
                // Initial data load logic is in ViewModel's init
                // If you want to refresh on appear:
                // viewModel.refreshSolarDataForCurrentCity()
            }
            // Refresh data when the app becomes active, e.g. after being in background
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                 print("App entering foreground, refreshing data...")
                 viewModel.refreshSolarDataForCurrentCity()
            }
        }
        .fontDesign(.rounded) // Apply rounded font design globally
    }

    @ViewBuilder
    private func customTopBar() -> some View {
        HStack(alignment: .center) {
            Button(action: {
                // TODO: Implement share
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .disabled(true) // Remove when implemented

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
                // TODO: Implement settings view
            }) {
                Image(systemName: "ellipsis.circle")
                     .font(.system(size: 18, weight: .medium))
                     .foregroundColor(.white)
            }
            .disabled(true) // Remove when implemented
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppColors.error)
                Text(message)
                    .font(.callout)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.primaryAccent)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)
            .padding(.horizontal)
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2.0)
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryAccent))
            
            Text("Fetching Solar Data...")
                .font(.headline)
                .foregroundColor(AppColors.secondaryText)

            // Placeholder for SunPathView
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .systemGray4))
                .frame(height: 250)
                .redacted(reason: .placeholder)
                .shimmer()


            // Placeholder for SolarDataListView
            VStack(alignment: .leading, spacing: 15) {
                ForEach(0..<5) { _ in
                    HStack {
                        RoundedRectangle(cornerRadius: 5).frame(width: 25, height: 25)
                        RoundedRectangle(cornerRadius: 5).frame(height: 20)
                        Spacer()
                        RoundedRectangle(cornerRadius: 5).frame(width: 80, height: 20)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)
            .redacted(reason: .placeholder)
            .shimmer()
            
        }
    }
}

// Shimmer effect for loading placeholders
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration: Double = 1.5
    var bounce: Bool = false

    func body(content: Content) -> some View {
        content
            .modifier(AnimatedMask(phase: phase).animation(
                Animation.linear(duration: duration)
                    .repeatForever(autoreverses: bounce)
            ))
            .onAppear { phase = 0.8 } // End phase for the shimmer effect
    }

    struct AnimatedMask: AnimatableModifier {
        var phase: CGFloat = 0

        var animatableData: CGFloat {
            get { phase }
            set { phase = newValue }
        }

        func body(content: Content) -> some View {
            content
                .mask(GradientMask(phase: phase).scaleEffect(3))
        }
    }

    struct GradientMask: View {
        let phase: CGFloat
        let centerColor = Color.black
        let edgeColor = Color.black.opacity(0.3)

        var body: some View {
            LinearGradient(gradient:
                Gradient(stops: [
                    .init(color: edgeColor, location: phase),
                    .init(color: centerColor, location: phase + 0.1),
                    .init(color: edgeColor, location: phase + 0.2)
                ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension View {
    @ViewBuilder
    func shimmer(duration: Double = 1.5, bounce: Bool = false) -> some View {
        self.modifier(ShimmerModifier(duration: duration, bounce: bounce))
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
