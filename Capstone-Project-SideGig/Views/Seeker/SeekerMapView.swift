import SwiftUI
import MapKit

struct SeekerMapView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationService = LocationService()
    @StateObject private var viewModel: SeekerMapViewModel
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    @State private var selectedGig: Gig?

    init() {
        // We can't access environment here, so create a placeholder. Will be replaced in .onAppear using appState.
        _viewModel = StateObject(wrappedValue: SeekerMapViewModel(backend: Back4AppService()))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: .constant(.region(region))) {
                    ForEach(viewModel.gigs) { gig in
                        let coordinate = CLLocationCoordinate2D(latitude: gig.latitude, longitude: gig.longitude)
                        Annotation(gig.title, coordinate: coordinate) {
                            Button(action: { selectedGig = gig }) {
                                Image(systemName: gig.gigType == "immediate" ? "mappin.circle.fill" : "mappin")
                                    .font(.title2)
                                    .foregroundStyle(gig.gigType == "immediate" ? .red : .blue)
                            }
                        }
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 8) {
                    if viewModel.isLoading { ProgressView().padding(8).background(.ultraThinMaterial).clipShape(Capsule()) }
                    if let error = viewModel.errorMessage { Text(error).padding(8).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 8)) }
                }
                .padding()
            }
            .navigationTitle("Gigs Near You")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(item: $selectedGig) { gig in
                GigDetailsView(gig: gig)
            }
            .onAppear {
                // Replace view model with one using the real backend from environment
                if type(of: viewModel) == SeekerMapViewModel.self {
                    // Already correct type; reassign with real backend if not same instance
                    let newVM = SeekerMapViewModel(backend: appState.backend)
                    _viewModel.wrappedValue = newVM
                }
                locationService.requestWhenInUse()
                if let loc = locationService.lastLocation {
                    region.center = loc.coordinate
                }
                refresh()
            }
            .onReceive(locationService.$lastLocation) { loc in
                guard let loc = loc else { return }
                region.center = loc.coordinate
            }
        }
    }

    private func refresh() {
        let center = region.center
        Task { await viewModel.loadNearbyGigs(center: center) }
    }
}

#Preview {
    SeekerMapView().environmentObject(AppState(backend: Back4AppService()))
}
