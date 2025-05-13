//
//  CitySearchView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI

struct CitySearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SunViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedCity.addedDate, ascending: false)],
        animation: .default)
    private var savedCities: FetchedResults<SavedCity>

    @State private var searchText: String = ""
    // Placeholder for actual API-based city search results
    @State private var cityApiSearchResults: [String] = ["New York", "London", "Tokyo", "Paris", "Berlin", "Cupertino", "San Francisco"]

    var filteredApiSearchResults: [String] {
        if searchText.isEmpty { return [] }
        // This simulates filtering API results. Replace with actual API call & filtering.
        return cityApiSearchResults.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                TextField("Search for a city...", text: $searchText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                Button(action: {
                    viewModel.requestCurrentLocationData()
                    // Consider dismissing only after location is confirmed or if user explicitly closes.
                    // For now, dismiss immediately.
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Use Current Location")
                        Spacer()
                        if viewModel.isLoadingLocation { ProgressView().scaleEffect(0.7) }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                // Button to add current search text if it's not empty, not in API results (for this demo), and not already saved
                if !searchText.isEmpty &&
                   !filteredApiSearchResults.contains(where: { $0.lowercased() == searchText.lowercased() }) &&
                   !savedCities.contains(where: { $0.name?.lowercased() == searchText.lowercased() }) {
                     Button(action: {
                        let cityNameToAdd = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cityNameToAdd.isEmpty {
                            addCity(name: cityNameToAdd)
                            viewModel.updateCityByName(name: cityNameToAdd)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add and select \"\(searchText)\"")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }

                List {
                    // Section for API Search Results (Placeholder)
                    if !filteredApiSearchResults.isEmpty {
                        Section("Search Results (Sample)") {
                            ForEach(filteredApiSearchResults, id: \.self) { cityName in
                                Button(action: {
                                    // If city not saved, add it. Then select.
                                    if !savedCities.contains(where: { $0.name == cityName }) {
                                        addCity(name: cityName)
                                    }
                                    viewModel.updateCityByName(name: cityName)
                                    dismiss()
                                }) {
                                    Text(cityName)
                                        .foregroundColor(.primary) // Ensure text is tappable color
                                }
                            }
                        }
                    }
                    
                    // Section for Saved Cities
                    Section(header: Text(savedCities.isEmpty && searchText.isEmpty && filteredApiSearchResults.isEmpty ? "No saved cities. Search to add or use current location." : "Saved Cities")) {
                        if savedCities.isEmpty && searchText.isEmpty && filteredApiSearchResults.isEmpty {
                             // Empty state text is now in the header
                        }
                        ForEach(savedCities) { cityEntity in
                            HStack {
                                Text(cityEntity.name ?? "Unknown City")
                                Spacer()
                                if viewModel.solarInfo.city == cityEntity.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle()) // Make the whole row tappable
                            .onTapGesture {
                                if let cityName = cityEntity.name {
                                    viewModel.updateCityByName(name: cityName)
                                    dismiss()
                                }
                            }
                        }
                        .onDelete(perform: deleteSavedCities)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Change Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addCity(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !savedCities.contains(where: { $0.name?.lowercased() == trimmedName.lowercased() }) else {
            print("City is empty or already saved: \(trimmedName)")
            return
        }
        withAnimation {
            let newCity = SavedCity(context: viewContext)
            newCity.id = UUID()
            newCity.name = trimmedName
            newCity.addedDate = Date()
            do {
                try viewContext.save()
                searchText = "" // Clear search text after successfully adding
            } catch {
                let nsError = error as NSError
                print("Error saving new city '\(trimmedName)': \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteSavedCities(offsets: IndexSet) {
        withAnimation {
            offsets.map { savedCities[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting city: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
