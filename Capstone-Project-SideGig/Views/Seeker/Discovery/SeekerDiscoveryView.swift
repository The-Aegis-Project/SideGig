//
//  SeekerDiscoveryView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/19/25.
//

import SwiftUI
import Combine
import CoreLocation

// MARK: - ViewModel
@MainActor
final class SeekerDiscoveryViewModel: ObservableObject {
    @Published var recommendedGigs: [Gig] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Using a placeholder location. A real app would get this from a location service.
    private let userLocation = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437) // Los Angeles

    private var backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    func updateBackend(_ backend: BackendService) {
        self.backend = backend
    }

    func loadRecommendations() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch nearby, open gigs as the "For You" recommendation logic.
            self.recommendedGigs = try await backend.fetchNearbyGigs(
                lat: userLocation.latitude,
                lng: userLocation.longitude,
                radiusMeters: 50000, // 50km radius
                payType: nil,
                gigType: nil,
                status: "open"
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}


// MARK: - Main View
struct SeekerDiscoveryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: SeekerDiscoveryViewModel
    @State private var selectedGig: Gig?

    init() {
        // We initialize with a placeholder, it will be updated onAppear
        _viewModel = StateObject(wrappedValue: SeekerDiscoveryViewModel(backend: Back4AppService()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Finding Gigs For You...")
                        .padding(.top, 50)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Something Went Wrong")
                            .font(.headline)
                            .padding(.top, 8)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding(.top, 50)
                } else if viewModel.recommendedGigs.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Recommendations Found")
                            .font(.headline)
                            .padding(.top, 8)
                        Text("We couldn't find any open gigs near you right now. Try expanding your search or check back later!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.recommendedGigs) { gig in
                            Button(action: {
                                selectedGig = gig
                            }) {
                                GigCardView(gig: gig)
                            }
                            .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to make the whole card tappable without visual changes
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Discovery Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshGigs) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.updateBackend(appState.backend)
                if viewModel.recommendedGigs.isEmpty { // Only load if empty
                    refreshGigs()
                }
            }
            .sheet(item: $selectedGig) { gig in
                // You'll need to have this view defined elsewhere
                // SeekerGigDetailsView(gig: gig).environmentObject(appState)
                Text("Gig Details for \(gig.title)")
            }
        }
    }

    private func refreshGigs() {
        Task {
            await viewModel.loadRecommendations()
        }
    }
}


// MARK: - Gig Card Subview
struct GigCardView: View {
    let gig: Gig

    private var accentColor: Color {
        gig.gigType == "immediate" ? .yellow : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with business logo and title
            HStack {
                // Business Logo Placeholder
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary.opacity(0.5))

                VStack(alignment: .leading) {
                    Text(gig.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    // You'd fetch the business name using gig.businessId
                    Text("Posted by Business Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            // Description
            Text(gig.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .padding(.horizontal)
                .padding(.bottom, 12)

            // Details pills (Pay & Type)
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                    Text("$\(gig.gigBudgetCents / 100)")
                        .fontWeight(.bold)
                    Text(gig.payType == "hourly" ? "/hr" : "flat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())

                HStack(spacing: 4) {
                    Image(systemName: gig.gigType == "immediate" ? "bolt.fill" : "calendar")
                    Text(gig.gigType.capitalized)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accentColor.opacity(0.15))
                .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal)

            // Footer with date
            HStack {
                Spacer()
                Text("Posted \(gig.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor, lineWidth: 2)
                .opacity(gig.gigType == "immediate" ? 0.8 : 0) // Only show for immediate gigs
        )
    }
}


// MARK: - Preview
#Preview {
    // Creating a mock AppState for the preview
    let mockBackend = Back4AppService() // Assuming a default initializer
    let appState = AppState(backend: mockBackend)

    // Creating a sample gig for the preview card
    let sampleGig = Gig(
        id: "1",
        businessId: "b1",
        title: "Urgent: Fix Leaky Pipe Under Sink",
        description: "There's a constant drip under the kitchen sink that needs immediate attention. Tools and parts will be discussed. Must have plumbing experience.",
        gigType: "immediate",
        payType: "flat-rate",
        gigBudgetCents: 15000,
        materialsBudgetCents: 5000,
        status: "open",
        latitude: 34.0,
        longitude: -118.0,
        createdAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
        isEscrowFunded: true,
        currency: "USD"
    )

    // Using a TabView to better simulate the real app environment
    return TabView {
        SeekerDiscoveryView()
            .environmentObject(appState)
            .tabItem { Label("For You", systemImage: "sparkles") }

        VStack {
             Text("Gig Card Preview")
             GigCardView(gig: sampleGig)
                .padding()
             Spacer()
        }
        .tabItem { Label("Card Preview", systemImage: "doc.richtext") }
    }
}
