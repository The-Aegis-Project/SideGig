import SwiftUI
import MapKit
import Contacts

struct SelectedLocation {
    let coordinate: CLLocationCoordinate2D
    let address: String
    let countryCode: String?
}

/// Lightweight identifiable wrapper used for map display
struct MapPlace: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let countryCode: String?
}

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery: String = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    @State private var selectedPlace: MapPlace?

    let onSelect: (SelectedLocation) -> Void

    private let completer = MKLocalSearchCompleter()
    @State private var completerDelegate: CompleterDelegate?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search for address or place", text: $searchQuery, onCommit: performSearch)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    Button("Search") { performSearch() }
                        .padding(.trailing)
                }

                Divider()

                if !results.isEmpty {
                    List(results.indices, id: \.self) { idx in
                        let item = results[idx]
                        Button(action: { selectCompletion(item) }) {
                            VStack(alignment: .leading) {
                                Text(item.title).font(.headline)
                                Text(item.subtitle).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    ZStack(alignment: .top) {
                        if #available(iOS 17.0, macOS 14.0, *) {
                            ModernMapView(region: $region) {
                                if let place = selectedPlace {
                                    pinOverlay(for: place)
                                }
                            }
                        } else {
                            // Use the MKCoordinateRegion-based initializer to remain compatible across SDKs
                            Map(coordinateRegion: $region)
                                .ignoresSafeArea(edges: .bottom)
                                .overlay(alignment: .center) {
                                    if let place = selectedPlace {
                                        pinOverlay(for: place)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Pick Location")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let p = selectedPlace {
                        Button("Confirm") {
                            let addr = [p.title, p.subtitle].compactMap { $0 }.joined(separator: ", ")
                            onSelect(SelectedLocation(coordinate: p.coordinate, address: addr, countryCode: p.countryCode))
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            completer.resultTypes = .address
            let d = CompleterDelegate(onUpdate: { comps in
                DispatchQueue.main.async { self.results = comps }
            })
            self.completerDelegate = d
            completer.delegate = d
        }
        .onChange(of: searchQuery) {
            completer.queryFragment = searchQuery
        }
    }

    @ViewBuilder
    private func pinOverlay(for place: MapPlace) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .shadow(radius: 2)
                .allowsHitTesting(false)
            if let title = place.title {
                Text(title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .allowsHitTesting(false)
            }
        }
        .offset(y: -20)
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchQuery
        let search = MKLocalSearch(request: req)
        Task {
            let res = try? await search.start()
            if let mapItem = res?.mapItems.first {
                let loc = mapItem.location
                let coordinate = loc.coordinate
                let title = mapItem.name
                // Avoid deprecated placemark APIs; do not rely on placemark.postalAddress here
                let subtitle: String? = nil
                let countryCode = countryCode(from: mapItem)

                DispatchQueue.main.async {
                    selectedPlace = MapPlace(coordinate: coordinate, title: title, subtitle: subtitle, countryCode: countryCode)
                    region.center = coordinate
                    results = []
                    searchQuery = title ?? searchQuery
                }
            }
        }
    }

    private func selectCompletion(_ comp: MKLocalSearchCompletion) {
        let req = MKLocalSearch.Request(completion: comp)
        let search = MKLocalSearch(request: req)
        Task {
            let res = try? await search.start()
            if let mapItem = res?.mapItems.first {
                let loc = mapItem.location
                let coordinate = loc.coordinate
                let countryCode = countryCode(from: mapItem)
                DispatchQueue.main.async {
                    selectedPlace = MapPlace(coordinate: coordinate, title: comp.title, subtitle: comp.subtitle, countryCode: countryCode)
                    region.center = coordinate
                    results = []
                    searchQuery = comp.title
                }
            }
        }
    }

    // Try to extract a country code from MKMapItem using newer MapKit API on iOS 26+,
    // falling back to the placemark's isoCountryCode on older OS versions.
    private func countryCode(from mapItem: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            // Try to inspect the `MKAddress` (or similar) using Mirror to find a country code field.
            if let addr = mapItem.address {
                let mirror = Mirror(reflecting: addr)
                for child in mirror.children {
                    if let label = child.label?.lowercased(), label.contains("country") {
                        if let cc = child.value as? String { return cc }
                    }
                }
            }

            // If addressRepresentations is available and iterable, try to inspect one entry.
            // `addressRepresentations` may not be a Sequence in all SDKs; be conservative and try KVC fallback if needed.
            if let repsObj = (mapItem.value(forKey: "addressRepresentations")) {
                let mirror = Mirror(reflecting: repsObj)
                // Try to find a child that contains country info
                for child in mirror.children {
                    let cMirror = Mirror(reflecting: child.value)
                    for ccChild in cMirror.children {
                        if let label = ccChild.label?.lowercased(), label.contains("country") {
                            if let cc = ccChild.value as? String { return cc }
                        }
                    }
                }
            }

            // As a last resort on newer OS, attempt KVC on the underlying placemark object if accessible
            if let placemarkObj = mapItem.value(forKey: "placemark") as? NSObject {
                if let cc = placemarkObj.value(forKey: "isoCountryCode") as? String { return cc }
                if let cc = placemarkObj.value(forKey: "countryCode") as? String { return cc }
            }

            return nil
        } else {
            // Use KVC to avoid referencing the deprecated `placemark` symbol directly
            if let placemarkObj = mapItem.value(forKey: "placemark") as? NSObject {
                if let cc = placemarkObj.value(forKey: "isoCountryCode") as? String { return cc }
                if let cc = placemarkObj.value(forKey: "countryCode") as? String { return cc }
            }
            return nil
        }
    }

    private func formatAddress(from postalAddress: CNPostalAddress?) -> String? {
        guard let address = postalAddress else { return nil }
        var components: [String] = []
        if !address.street.isEmpty { components.append(address.street) }
        if !address.city.isEmpty { components.append(address.city) }
        if !address.state.isEmpty { components.append(address.state) }
        if !address.postalCode.isEmpty { components.append(address.postalCode) }
        let final = components.filter { !$0.isEmpty }
        return final.isEmpty ? nil : final.joined(separator: ", ")
    }
}

/// A wrapper for `CLLocationCoordinate2D` to make it `Equatable`.
fileprivate struct EquatableCoordinate: Equatable {
    let coordinate: CLLocationCoordinate2D

    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    static func == (lhs: EquatableCoordinate, rhs: EquatableCoordinate) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ModernMapView<Content: View>: View {
    @Binding var region: MKCoordinateRegion
    @ViewBuilder let content: () -> Content
    
    @State private var position: MapCameraPosition

    init(region: Binding<MKCoordinateRegion>, @ViewBuilder content: @escaping () -> Content) {
        self._region = region
        self.content = content
        self._position = State(initialValue: .region(region.wrappedValue))
    }
    
    var body: some View {
        Map(position: $position)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .center) {
                content()
            }
            .onChange(of: EquatableCoordinate(region.center)) {
                position = .region(region)
            }
            .onMapCameraChange { context in
                region = context.region
            }
    }
}

private class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onUpdate: ([MKLocalSearchCompletion]) -> Void
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) { self.onUpdate = onUpdate }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) { onUpdate(completer.results) }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("MKLocalSearchCompleter failed: \(error)")
        onUpdate([])
    }
}
