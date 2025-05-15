//
//  CitySearchView.swift
//  Solar
//
//  Created by Tyler Reckart on 5/13/25.
//

import SwiftUI
import CoreLocation

struct CitySearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SunViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedCity.addedDate, ascending: false)],
        animation: .default)
    private var savedCities: FetchedResults<SavedCity>

    @State private var searchText: String = ""
    // Replace with actual API-based city search results (this is a future enhancement)
    @State private var cityApiSearchResults: [String] = ["New York", "London", "Tokyo", "Paris", "Berlin"]
    @State private var geocodingError: String? = nil
    @State private var liveSearchResults: [CLPlacemark] = []
    @State private var isSearchingCities: Bool = false


    var filteredApiSearchResults: [String] {
        if searchText.isEmpty { return [] } // No API results for empty search
        return cityApiSearchResults.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                TextField("Search for a city...", text: $searchText)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .onSubmit { // Allow submitting search via keyboard
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                             addAndSelectSearchedCity(name: searchText)
                        }
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        // Basic debounce: only search if text is not empty and has changed
                        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedQuery.isEmpty && trimmedQuery.count > 2 { // Start searching after 2 characters
                            // You might want to add a slight delay (debounce) here in a real app
                            performLiveCitySearch(query: trimmedQuery)
                        } else {
                            liveSearchResults = [] // Clear results if search text is short or empty
                        }
                    }
                
                if let error = geocodingError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                        .padding(.horizontal)
                }

                Button(action: {
                    viewModel.requestSolarDataForCurrentLocation()
                    // Dismissal should ideally happen after successful location fetch or user cancels.
                    // For now, we dismiss, and the main view will update.
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Use Current Location")
                        Spacer()
                        if viewModel.isFetchingLocationDetails { ProgressView().tint(AppColors.primaryAccent) }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.primaryAccent.opacity(0.15))
                    .foregroundColor(AppColors.primaryAccent)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                // This button is for directly adding the text if it's not in the (demo) API results
                // and not already saved.
                let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSearchText.isEmpty &&
                   !filteredApiSearchResults.contains(where: { $0.lowercased() == trimmedSearchText.lowercased() }) &&
                   !savedCities.contains(where: { $0.name?.lowercased() == trimmedSearchText.lowercased() }) {
                     Button(action: {
                        addAndSelectSearchedCity(name: trimmedSearchText)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add and select \"\(trimmedSearchText)\"")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }


                List {
                    if isSearchingCities {
                        Section("Suggestions") {
                            ProgressView()
                        }
                    } else if !liveSearchResults.isEmpty {
                        Section("Suggestions") { // Changed from "Suggestions (Sample)"
                            ForEach(liveSearchResults, id: \.self) { placemark in // Iterate CLPlacemark
                                Button(action: {
                                    handlePlacemarkSelection(placemark)
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(placemark.locality ?? placemark.name ?? "Unknown place")
                                            .foregroundColor(Color(uiColor: .label))
                                        if let country = placemark.country {
                                            Text(country)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text(savedCities.isEmpty && searchText.isEmpty && filteredApiSearchResults.isEmpty ? "No saved cities. Search to add or use current location." : "Saved Cities").font(.caption).foregroundColor(AppColors.secondaryText)) {
                        if savedCities.isEmpty && searchText.isEmpty && filteredApiSearchResults.isEmpty {
                             // Empty state text is now in the header
                        } else {
                            ForEach(savedCities) { cityEntity in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(cityEntity.name ?? "Unknown City")
                                            .foregroundColor(Color(uiColor: .label))
                                        if let date = cityEntity.addedDate {
                                            Text("Added: \(date, style: .date)")
                                                .font(.caption2)
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                    }
                                    Spacer()
                                    if viewModel.solarInfo.city.lowercased() == cityEntity.name?.lowercased() {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.primaryAccent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let cityName = cityEntity.name {
                                        handleCitySelection(name: cityName, fromApi: false)
                                    }
                                }
                            }
                            .onDelete(perform: deleteSavedCities)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle()) // Modern list style
            }
            .navigationTitle("Change Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.primaryAccent)
                }
            }
        }
        .tint(AppColors.primaryAccent) // Sets accent for NavigationView elements like "Done"
    }
    
    private func performLiveCitySearch(query: String) {
        geocodingError = nil
        isSearchingCities = true
        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(query) { [self] (placemarks, error) in
            isSearchingCities = false
            if let error = error {
                // Avoid showing an error for every keystroke if it's a common "not found yet"
                if (error as NSError).code == CLError.geocodeFoundNoResult.rawValue || (error as NSError).code == CLError.geocodeFoundPartialResult.rawValue {
                    // User is likely still typing
                    self.liveSearchResults = []
                } else if (error as NSError).code != CLError.geocodeCanceled.rawValue {
                    self.geocodingError = "Search error: \(error.localizedDescription)"
                    self.liveSearchResults = []
                }
                return
            }

            guard let placemarks = placemarks else {
                self.liveSearchResults = []
                return
            }

            // Filter out results without a locality or name to make them more user-friendly
            self.liveSearchResults = placemarks.filter { $0.locality != nil || $0.name != nil }
        }
    }
    
    private func handlePlacemarkSelection(_ placemark: CLPlacemark) {
        guard let location = placemark.location else {
            geocodingError = "Could not get coordinates for the selected location."
            return
        }

        let bestName = placemark.locality ?? placemark.name ?? "Selected Location"
        let clTimezoneIdentifier = placemark.timeZone?.identifier

        // Add to saved cities if not already there (using bestName)
        if !savedCities.contains(where: { $0.name?.lowercased() == bestName.lowercased() }) {
            addCityToCoreData(name: bestName,
                              lat: location.coordinate.latitude,
                              lon: location.coordinate.longitude,
                              timezoneId: clTimezoneIdentifier)
        }

        // Update ViewModel and dismiss
        viewModel.selectCity(name: bestName,
                             latitude: location.coordinate.latitude,
                             longitude: location.coordinate.longitude,
                             timezoneIdentifier: clTimezoneIdentifier)
        dismiss()
    }
    
    
    private func addAndSelectSearchedCity(name: String) {
        geocodingError = nil
        let geocoder = CLGeocoder()
        viewModel.isGeocodingCity = true
        geocoder.geocodeAddressString(name) { [self] (placemarks, error) in
            viewModel.isGeocodingCity = false
            if let error = error {
                self.geocodingError = "Error finding '\(name)': \(error.localizedDescription)"
                return
            }
            guard let placemark = placemarks?.first, let location = placemark.location else {
                self.geocodingError = "Could not find coordinates for '\(name)'."
                return
            }
            
            let bestName = placemark.locality ?? placemark.name ?? name
            let clTimezoneIdentifier = placemark.timeZone?.identifier // Get timezone from placemark
            
            // Add to saved cities if not already there
            if !savedCities.contains(where: { $0.name?.lowercased() == bestName.lowercased() }) {
                addCityToCoreData(name: bestName, lat: location.coordinate.latitude, lon: location.coordinate.longitude, timezoneId: clTimezoneIdentifier)
            }
            
            // Update ViewModel and dismiss
            viewModel.selectCity(name: bestName, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, timezoneIdentifier: clTimezoneIdentifier)
            dismiss()
        }
    }

    private func handleCitySelection(name: String, fromApi: Bool) {
        geocodingError = nil
        // If from API demo or a new search, we always geocode to get lat/lon
        // If from saved cities, we assume lat/lon might be stored, but for consistency let's re-geocode
        // or extend SavedCity to store lat/lon. For now, always geocode.
        
        // Check if city is already saved to retrieve its lat/lon if we were storing it
        if let saved = savedCities.first(where: { $0.name?.lowercased() == name.lowercased() }),
           let savedLat = saved.latitude as? Double, let savedLon = saved.longitude as? Double,
           savedLat != 0 && savedLon != 0 {
            print("Using saved coordinates for \(name)")
            // Pass the saved timezone identifier if you stored it
            viewModel.selectCity(name: name, latitude: savedLat, longitude: savedLon, timezoneIdentifier: saved.timezoneId)
            dismiss()
        } else {
            // geocodeAndSelectCity in ViewModel will attempt to get timezone from CLPlacemark
            // and then from API.
            viewModel.geocodeAndSelectCity(name: name)
            dismiss()
        }
    }

    private func addCityToCoreData(name: String, lat: Double? = nil, lon: Double? = nil, timezoneId: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !savedCities.contains(where: { $0.name?.lowercased() == trimmedName.lowercased() }) else {
            print("City is empty or already saved: \(trimmedName)")
            return
        }
        withAnimation {
            let newCity = SavedCity(context: viewContext)
            newCity.id = UUID()
            newCity.name = name // Already trimmed from caller
            newCity.addedDate = Date()
            if let lat = lat, let lon = lon {
                newCity.latitude = lat
                newCity.longitude = lon
            }
            newCity.timezoneId = timezoneId // Store the timezone identifier
            // ... save context ...
            do {
                try viewContext.save()
                searchText = ""
                print("Saved city: \(name) with TZ: \(timezoneId ?? "N/A")")
            } catch {
                let nsError = error as NSError
                print("Error saving new city '\(name)': \(nsError), \(nsError.userInfo)")
                self.geocodingError = "Could not save city: \(nsError.localizedDescription)"
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
                self.geocodingError = "Could not delete city: \(nsError.localizedDescription)"
            }
        }
    }
}
