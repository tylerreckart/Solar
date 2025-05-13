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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.gray.opacity(0.2))
                            .clipShape(Circle())
                        Spacer()
                        HStack(alignment: .center) {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(viewModel.solarInfo.city)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.vertical, 5)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.blue.opacity(0.2))
                        .clipShape(Capsule())
                        .onTapGesture {
                            showingCitySearchSheet = true
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.horizontal)

                    SunPathView(progress: viewModel.solarInfo.sunProgress, solarNoonProgress: 0.5)
                        .frame(height: 250)
                        .padding(.horizontal)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)

                    SolarDataListView(solarInfo: viewModel.solarInfo, viewModel: viewModel)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCitySearchSheet) {
                CitySearchView(viewModel: viewModel)
                    .environment(\.managedObjectContext, self.viewContext)
            }
             .onAppear {
                viewModel.requestCurrentLocationData()
             }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
