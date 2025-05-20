// Solar/Views/CitySearchView.swift
import SwiftUI
import CoreLocation
import Combine

// Helper struct CitySearchResult (no changes)
struct CitySearchResult: Identifiable, Hashable {
    let id = UUID()
    let placemark: CLPlacemark

    var primaryText: String {
        placemark.locality ?? placemark.name ?? "Unknown Location"
    }

    var secondaryText: String {
        var parts: [String] = []
        if let adminArea = placemark.administrativeArea, adminArea != primaryText {
            parts.append(adminArea)
        }
        if let country = placemark.country {
            parts.append(country)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(placemark)
    }

    static func == (lhs: CitySearchResult, rhs: CitySearchResult) -> Bool {
        lhs.placemark == rhs.placemark
    }
}

struct CitySearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SunViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedCity.addedDate, ascending: false)],
        animation: .default)
    private var savedCities: FetchedResults<SavedCity>

    @State private var searchText: String = ""
    @State private var displayedSearchResults: [CitySearchResult] = []
    @State private var isSearchingCities: Bool = false
    @State private var geocodingError: String? = nil
    @State private var isInEditMode: Bool = false
    
    @State private var searchDebounceTask: DispatchWorkItem?

    var body: some View {
        NavigationView {
            ScrollView {
                searchBar()
                geocodingErrorView()
                currentLocationButton()
                liveSearchResultsSection()
                savedCitiesSection()
                Spacer() // Pushes content to top
            }
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if isInEditMode { isInEditMode = false }
                        dismiss()
                    }.foregroundColor(AppColors.primaryAccent)
                }
                ToolbarItem(placement: .principal) {
                    Text("Change Location").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .tint(AppColors.primaryAccent)
    }

    // MARK: - Helper Views / Computed Properties

    @ViewBuilder
    private func searchBar() -> some View {
        TextField("Search for a city...", text: $searchText)
            .padding()
            .background(AppColors.ui)
            .foregroundColor(.white)
            .cornerRadius(16)
            .padding(.horizontal)
            .onSubmit {
                let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedQuery.isEmpty {
                    searchDebounceTask?.cancel()
                    performLiveCitySearch(query: trimmedQuery, isSubmit: true)
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                geocodingError = nil
                searchDebounceTask?.cancel()

                let task = DispatchWorkItem {
                    let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedQuery.isEmpty && trimmedQuery.count > 1 {
                        performLiveCitySearch(query: trimmedQuery)
                    } else {
                        Task { @MainActor in
                            self.displayedSearchResults = []
                            self.isSearchingCities = false
                        }
                    }
                }
                self.searchDebounceTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
            }
    }

    @ViewBuilder
    private func geocodingErrorView() -> some View {
        if let error = geocodingError, !isSearchingCities {
            Text(error)
                .font(.caption)
                .foregroundColor(AppColors.error)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func currentLocationButton() -> some View {
        Button(action: {
            viewModel.requestSolarDataForCurrentLocation()
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
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.top, 5)
    }

    @ViewBuilder
    private func liveSearchResultsSection() -> some View {
        if isSearchingCities {
            HStack {
                ProgressView().padding(.trailing, 5)
                Text("Searching cities...").font(.caption).foregroundColor(.gray)
            }
            .padding().frame(maxWidth: .infinity, alignment: .center)
        } else if !displayedSearchResults.isEmpty {
            Section {
                VStack(spacing: 0) {
                    ForEach(displayedSearchResults) { result in
                        searchResultRow(for: result)
                    }
                }
                .padding(.horizontal)
                .background(AppColors.ui)
                .cornerRadius(16)
                .padding(.horizontal)
            } header: {
                HStack {
                    Text("Suggestions").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(.systemGray)).textCase(nil)
                    Spacer()
                }
                .padding(.horizontal, 25).padding(.top)
            }
        }
    }

    @ViewBuilder
    private func searchResultRow(for result: CitySearchResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.primaryText).font(.system(size: 16, weight: .regular)).foregroundColor(.white)
                    if !result.secondaryText.isEmpty {
                        Text(result.secondaryText).font(.system(size: 13)).foregroundColor(AppColors.secondaryText)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12).contentShape(Rectangle())
            .onTapGesture { handlePlacemarkSelection(result) }
            
            if result.id != displayedSearchResults.last?.id {
                Divider().background(Color.gray.opacity(0.2))
            }
        }
    }

    @ViewBuilder
    private func savedCitiesSection() -> some View {
        Section {
            if savedCities.isEmpty && displayedSearchResults.isEmpty && searchText.isEmpty && !isSearchingCities {
                 Text("Search for a city or use your current location.")
                    .font(.caption).foregroundColor(.gray).padding().frame(maxWidth: .infinity, alignment: .center)
            } else if !savedCities.isEmpty {
                VStack(spacing: 0) {
                    ForEach(savedCities) { cityEntity in
                        savedCityRow(for: cityEntity)
                    }
                }
                .animation(.default, value: isInEditMode) // Animate changes within the list due to edit mode
                .padding(.horizontal)
                .background(AppColors.ui)
                .cornerRadius(16)
                .padding(.horizontal)
            }
        } header: {
            HStack {
                Text("Saved Cities").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(.systemGray)).textCase(nil)
                Spacer()
                if !savedCities.isEmpty {
                    Button(action: {
                        withAnimation { isInEditMode.toggle() }
                    }) {
                        Text(isInEditMode ? "Done" : "Edit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primaryAccent)
                    }
                }
            }
            .padding(.horizontal, 25).padding(.top)
        }
    }

    @ViewBuilder
    private func savedCityRow(for cityEntity: SavedCity) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                if isInEditMode {
                    Button { deleteSavedCity(cityEntity) } label: {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red).font(.title2)
                    }
                    .padding(.leading, 5)
                }
                
                VStack(alignment: .leading) {
                    Text(cityEntity.name ?? "Unknown City").font(.system(size: 16, weight: .regular)).foregroundColor(.white).padding(.bottom, 2)
                    if let date = cityEntity.addedDate {
                        Text("Added: \(date, style: .date)").font(.caption2).foregroundColor(AppColors.secondaryText)
                    }
                }
                Spacer()
                if !isInEditMode && viewModel.solarInfo.city.lowercased() == cityEntity.name?.lowercased() {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.primaryAccent)
                }
            }
            .padding(.vertical, 12).contentShape(Rectangle())
            .onTapGesture {
                if !isInEditMode {
                    Task { // Ensure async operations from onTapGesture are in a Task
                        if let cityName = cityEntity.name {
                            let lat = cityEntity.latitude as? Double
                            let lon = cityEntity.longitude as? Double
                            let tzId = cityEntity.timezoneId
                            if lat != 0 && lon != 0 {
                                 viewModel.selectCity(name: cityName, latitude: lat, longitude: lon, timezoneIdentifier: tzId)
                            } else {
                                 await viewModel.geocodeAndSelectCity(name: cityName) // Made geocodeAndSelectCity async in ViewModel if it wasn't
                            }
                            dismiss()
                        }
                    }
                }
            }
            if cityEntity.id != savedCities.last?.id {
                Divider().background(Color.gray.opacity(0.2))
                    .padding(.leading, isInEditMode ? 45 : 0)
            }
        }
    }
    
    // MARK: - Methods (performLiveCitySearch, handlePlacemarkSelection, etc. remain the same)

    private func performLiveCitySearch(query: String, isSubmit: Bool = false) {
        Task { @MainActor in
            self.isSearchingCities = true
            self.geocodingError = nil
            self.displayedSearchResults = []
        }

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, error in
            Task { @MainActor in
                self.isSearchingCities = false
                if let error = error as? NSError {
                    if error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError { return }
                    if error.code == CLError.geocodeFoundNoResult.rawValue || error.code == CLError.geocodeFoundPartialResult.rawValue {
                        if isSubmit { self.geocodingError = "No cities found matching \"\(query)\"." }
                        else { self.geocodingError = nil }
                    } else if error.code != CLError.network.rawValue && error.code != CLError.geocodeCanceled.rawValue {
                        self.geocodingError = "Search error: \(error.localizedDescription)"
                    }
                    self.displayedSearchResults = []
                    return
                }

                guard let validPlacemarks = placemarks else {
                    self.displayedSearchResults = []
                    if isSubmit { self.geocodingError = "No cities found matching \"\(query)\"." }
                    return
                }

                let mappedResults = validPlacemarks
                    .compactMap { placemark -> CitySearchResult? in
                        guard (placemark.locality != nil || placemark.name != nil), placemark.location != nil else { return nil }
                        return CitySearchResult(placemark: placemark)
                    }
                    .reduce(into: [CitySearchResult]()) { (uniqueResults, currentResult) in
                        if !uniqueResults.contains(where: { $0.primaryText == currentResult.primaryText && $0.secondaryText == currentResult.secondaryText }) {
                            uniqueResults.append(currentResult)
                        }
                    }
                self.displayedSearchResults = Array(mappedResults.prefix(10))
                if self.displayedSearchResults.isEmpty && isSubmit {
                    self.geocodingError = "No cities found matching \"\(query)\"."
                }
            }
        }
    }
    
    private func handlePlacemarkSelection(_ result: CitySearchResult) {
        guard let location = result.placemark.location else {
            geocodingError = "Could not get coordinates for the selected location."
            return
        }
        let bestName = result.placemark.locality ?? result.placemark.name ?? "Selected Location"
        let clTimezoneIdentifier = result.placemark.timeZone?.identifier
        if !savedCities.contains(where: { $0.name?.lowercased() == bestName.lowercased() }) {
            addCityToCoreData(name: bestName, lat: location.coordinate.latitude, lon: location.coordinate.longitude, timezoneId: clTimezoneIdentifier, placemark: result.placemark)
        }
        viewModel.selectCity(name: bestName, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, timezoneIdentifier: clTimezoneIdentifier)
        dismiss()
    }

    private func addCityToCoreData(name: String, lat: Double?, lon: Double?, timezoneId: String?, placemark: CLPlacemark? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !savedCities.contains(where: { $0.name?.lowercased() == trimmedName.lowercased() }) else { return }
        let newCity = SavedCity(context: viewContext)
        newCity.id = UUID(); newCity.name = trimmedName; newCity.addedDate = Date()
        if let lat = lat, let lon = lon { newCity.latitude = lat; newCity.longitude = lon }
        newCity.timezoneId = timezoneId
        do {
            try viewContext.save(); searchText = ""
        } catch {
            let nsError = error as NSError
            Task { @MainActor in self.geocodingError = "Could not save city: \(nsError.localizedDescription)" }
        }
    }

    private func deleteSavedCity(_ city: SavedCity) {
        withAnimation {
            viewContext.delete(city)
            do {
                try viewContext.save()
                if savedCities.isEmpty { isInEditMode = false }
            } catch {
                let nsError = error as NSError
                Task { @MainActor in self.geocodingError = "Could not delete city: \(nsError.localizedDescription)" }
            }
        }
    }
    
    // This function can be removed if not used by a swipe-to-delete on a standard List.
    // For the custom implementation, deleteSavedCity(_ city: SavedCity) is used.
    // private func deleteSavedCities(offsets: IndexSet) { ... }
}
