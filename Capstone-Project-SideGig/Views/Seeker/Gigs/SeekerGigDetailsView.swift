//
//  SeekerGigDetailsView.swift
//  Capstone-Project-SideGig
//
//  Created by GitHub Copilot on 11/16/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct SeekerGigDetailsView: View {
    @EnvironmentObject var appState: AppState
    let gig: Gig
    @State private var isLoading = false
    @State private var message: String?
    @State private var address: String? = nil
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    Text(gig.title)
                        .font(.title2).bold()
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        // Pay
                        Text(formattedCurrency(cents: gig.gigBudgetCents, currencyCode: gig.currency))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.black.opacity(0.15))
                            .clipShape(Capsule())

                        // Type chip
                        Text(gig.gigType.capitalized)
                            .font(.caption)
                            .padding(6)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Spacer()

                        Text(relativeDate(from: gig.createdAt))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color(.systemIndigo), Color(.systemPurple)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    Text(gig.description.isEmpty ? "No description provided." : gig.description)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Location and map
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)

                    HStack(alignment: .top, spacing: 12) {
                        Map(position: $cameraPosition, interactionModes: []) {
                            Annotation(gig.title, coordinate: CLLocationCoordinate2D(latitude: gig.latitude, longitude: gig.longitude)) {
                                // Custom view for the annotation to show the gig title and a pin icon
                                VStack(spacing: 0) {
                                    Text(gig.title)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(.white).opacity(0.8))
                                        .shadow(radius: 1)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .offset(y: -5) // Adjust offset to position the pin correctly
                                }
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 6) {
                            if let addr = address {
                                Text(addr)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            } else {
                                Text(String(format: "Lat: %.4f, Lon: %.4f", gig.latitude, gig.longitude))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Button(action: openInMaps) {
                                Label("Open in Maps", systemImage: "map")
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Messages & actions
                if let msg = message { Text(msg).foregroundColor(.secondary).font(.caption) }

                Button(action: apply) {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text("Apply")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Gig")
        .onAppear {
            cameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: gig.latitude, longitude: gig.longitude), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            Task.detached { await fetchAddress() }
        }
    }

    private func apply() {
        Task { @MainActor in
            guard let seekerId = appState.backend.currentUserId else { message = "Sign in to apply"; return }
            isLoading = true
            do {
                _ = try await appState.backend.applyForGig(gigId: gig.id, seekerId: seekerId)
                message = "Application submitted"
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func fetchAddress() async {
        // Use CLGeocoder for a human-readable address; this may warn about deprecation on newer SDKs but remains functional.
        let loc = CLLocation(latitude: gig.latitude, longitude: gig.longitude)
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(loc)
            if let p = placemarks.first {
                var parts: [String] = []
                if let name = p.name { parts.append(name) }
                if let thoroughfare = p.thoroughfare { parts.append(thoroughfare) }
                if let locality = p.locality { parts.append(locality) }
                if let administrative = p.administrativeArea { parts.append(administrative) }
                if let country = p.country { parts.append(country) }
                let addr = parts.joined(separator: ", ")
                await MainActor.run { address = addr.isEmpty ? nil : addr }
            }
        } catch {
            // ignore - leave address nil which will render coordinates
        }
    }

    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: gig.latitude, longitude: gig.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = gig.title
        mapItem.openInMaps(launchOptions: nil)
    }

    private func formattedCurrency(cents: Int, currencyCode: String) -> String {
        let amount = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, currencyCode)
    }

    private func relativeDate(from date: Date) -> String {
        let df = RelativeDateTimeFormatter()
        df.unitsStyle = .short
        return df.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    let sample = Gig(id: "g1", businessId: "b1", assignedSeekerId: nil, title: "Test", description: "Test description of the gig. Please bring your own tools and be on time.", gigType: "immediate", payType: "flat-rate", gigBudgetCents: 1000, materialsBudgetCents: 0, status: "open", latitude: 40.7128, longitude: -74.0060, createdAt: Date().addingTimeInterval(-3600), agreementId: nil, receiptImageUrl: nil, isEscrowFunded: false, currency: "USD")
    SeekerGigDetailsView(gig: sample).environmentObject(AppState(backend: Back4AppService()))
}

