import Foundation
import CoreLocation

@MainActor
final class SeekerMapViewModel: ObservableObject {
    @Published var gigs: [Gig] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    func loadNearbyGigs(center: CLLocationCoordinate2D, radiusMeters: Double = 3000) async {
        isLoading = true
        errorMessage = nil
        do {
            let results = try await backend.fetchNearbyGigs(lat: center.latitude, lng: center.longitude, radiusMeters: radiusMeters)
            self.gigs = results
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
