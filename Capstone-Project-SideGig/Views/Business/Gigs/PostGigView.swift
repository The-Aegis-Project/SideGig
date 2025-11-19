import SwiftUI
import CoreLocation
import MapKit

struct PostGigView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) private var presentationMode

    @State private var title = ""
    @State private var description = ""
    @State private var gigType = "standard"
    @State private var payType = "flat-rate"
    @State private var gigBudgetCents = ""
    @State private var materialsBudgetCents = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var selectedAddress: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showingLocationPicker = false
    @State private var saveAsMainLocation = false
    @State private var saveAsFavorite = false
    @State private var favoriteName = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showingConfirm = false
    @State private var showingSuccess = false
    @State private var currency: String = "USD"

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $title)
                TextField("Description", text: $description)
            }

            Section("Type & Pay") {
                Picker("Gig Type", selection: $gigType) {
                    Text("Standard").tag("standard")
                    Text("Immediate").tag("immediate")
                }
                Picker("Pay Type", selection: $payType) {
                    Text("Flat").tag("flat-rate")
                    Text("Hourly").tag("hourly")
                }
                TextField("Budget (cents)", text: $gigBudgetCents).keyboardType(.numberPad)
                TextField("Materials Budget (cents)", text: $materialsBudgetCents).keyboardType(.numberPad)
                HStack {
                    Text("Currency")
                    Spacer()
                    Text(currency).foregroundColor(.secondary)
                }
            }

            Section("Location") {
                if let addr = selectedAddress, let coord = selectedCoordinate {
                    VStack(alignment: .leading) {
                        Text(addr).font(.subheadline)
                        Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude)).font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    Text("No location selected").foregroundColor(.secondary)
                }

                Button("Pick Location") { showingLocationPicker = true }

                Toggle("Save as business main location", isOn: $saveAsMainLocation)
                Toggle("Save as favorite location", isOn: $saveAsFavorite)
                if saveAsFavorite {
                    TextField("Favorite name (optional)", text: $favoriteName)
                }
            }

            if let msg = errorMessage { Section { Text(msg).foregroundColor(.red) } }

            Section {
                Button(action: { showingConfirm = true }) {
                    if isSubmitting { ProgressView() } else { Text("Post Gig") }
                }
                .disabled(isSubmitting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Post Gig")
        .alert("Confirm Post", isPresented: $showingConfirm) {
            Button("Post", role: .destructive) { Task { await confirmSubmit() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Post this gig with title:\n\n\(title)\n\nBudget: $\(String(format: "%.2f", Double(Int(gigBudgetCents) ?? 0)/100.0))")
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") { presentationMode.wrappedValue.dismiss() }
        } message: { Text("Gig posted successfully.") }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView { selected in
                selectedCoordinate = selected.coordinate
                selectedAddress = selected.address
                showingLocationPicker = false
                // Use country code provided by LocationPickerView (preferred over CLGeocoder)
                if let cc = selected.countryCode {
                    currency = currencyCode(for: cc) ?? "USD"
                } else {
                    currency = "USD"
                }
            }
        }
    }

    // Minimal country -> currency mapping; extend if needed
    private func currencyCode(for countryCode: String) -> String? {
        // Common mappings
        let map: [String: String] = [
            "US": "USD",
            "CA": "CAD",
            "GB": "GBP",
            "EU": "EUR",
            "FR": "EUR",
            "DE": "EUR",
            "JP": "JPY",
            "AU": "AUD",
            "MX": "MXN"
        ]
        return map[countryCode.uppercased()]
    }

    private func confirmSubmit() async {
        // Basic validation
        if let err = validate() {
            errorMessage = err
            return
        }
        await submit()
    }

    private func validate() -> String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Title is required." }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Description is required." }
        if let g = Int(gigBudgetCents), g < 0 { return "Budget must be non-negative." }
        if let m = Int(materialsBudgetCents), m < 0 { return "Materials budget must be non-negative." }
        if selectedCoordinate == nil { return "Please pick a location for the gig." }
        return nil
    }

    private func submit() async {
        guard let businessId = appState.backend.currentUserId else { errorMessage = "Sign in as business"; return }
        isSubmitting = true; errorMessage = nil
        do {
            let gBudget = Int(gigBudgetCents) ?? 0
            let mBudget = Int(materialsBudgetCents) ?? 0
            let coord = selectedCoordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            _ = try await appState.backend.createGig(businessId: businessId, title: title, description: description, gigType: gigType, payType: payType, gigBudgetCents: gBudget, materialsBudgetCents: mBudget, latitude: coord.latitude, longitude: coord.longitude, currency: currency)

            // If requested, save as main business location
            if saveAsMainLocation {
                if var profile = try await appState.backend.fetchBusinessProfile(userId: businessId) {
                    profile.latitude = coord.latitude
                    profile.longitude = coord.longitude
                    profile.address = selectedAddress ?? profile.address
                    _ = try await appState.backend.updateBusinessProfile(profile: profile)
                }
            }

            // If requested, save as favorite
            if saveAsFavorite {
                let _ = try await appState.backend.saveFavoriteLocation(businessId: businessId, name: favoriteName.isEmpty ? nil : favoriteName, latitude: coord.latitude, longitude: coord.longitude)
            }
            // Reset the form back to defaults on success
            await MainActor.run {
                resetForm()
                showingSuccess = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    // Reset form fields to defaults
    private func resetForm() {
        title = ""
        description = ""
        gigType = "standard"
        payType = "flat-rate"
        gigBudgetCents = ""
        materialsBudgetCents = ""
        latitude = ""
        longitude = ""
        selectedAddress = nil
        selectedCoordinate = nil
        showingLocationPicker = false
        saveAsMainLocation = false
        saveAsFavorite = false
        favoriteName = ""
        isSubmitting = false
        errorMessage = nil
        showingConfirm = false
        currency = "USD"
    }
}

#Preview {
    PostGigView().environmentObject(AppState(backend: Back4AppService()))
}
