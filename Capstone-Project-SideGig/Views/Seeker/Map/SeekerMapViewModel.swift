//
//  SeekerMapViewModel.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class SeekerMapViewModel: ObservableObject {
    @Published var gigs: [Gig] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    // Allow replacing the backend instance after initialization (used by the view)
    func updateBackend(_ backend: BackendService) {
        self.backend = backend
    }

    func loadNearbyGigs(center: CLLocationCoordinate2D, radiusMeters: Double = 3000) async {
        isLoading = true
        errorMessage = nil
        do {
            let results = try await backend.fetchNearbyGigs(lat: center.latitude, lng: center.longitude, radiusMeters: radiusMeters, payType: nil, gigType: nil, status: nil)
            self.gigs = results
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Fetch full gig details from the backend for a specific gig id.
    /// Returns the domain `Gig` if found, otherwise nil.
    func fetchGigDetails(gigId: String) async -> Gig? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let gig = try await backend.fetchGigDetails(gigId: gigId) {
                return gig
            } else {
                errorMessage = "Gig not found"
                return nil
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
