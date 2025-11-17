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
}
