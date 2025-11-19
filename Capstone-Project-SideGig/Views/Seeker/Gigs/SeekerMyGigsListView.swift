//
//  SeekerMyGigsListView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/20/25.
//

import SwiftUI
import Combine

@MainActor
final class SeekerGigsViewModel: ObservableObject {
    @Published var categorizedGigs: [SeekerGigStatus: [Gig]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func gigs(for status: SeekerGigStatus) -> [Gig] {
        categorizedGigs[status] ?? []
    }

    private var backend: BackendService
    private var seekerId: String?

    init(backend: BackendService, seekerId: String?) {
        self.backend = backend
        self.seekerId = seekerId
    }

    func updateBackend(_ backend: BackendService) {
        self.backend = backend
    }

    func updateSeekerId(_ id: String?) {
        self.seekerId = id
    }

    func loadGigs() async {
        guard let seekerId = seekerId else {
            errorMessage = "Seeker ID not available."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // This assumes `fetchSeekerGigs` is part of the BackendService protocol.
            self.categorizedGigs = try await backend.fetchSeekerGigs(seekerId: seekerId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct SeekerGigsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: SeekerGigsViewModel
    
    @State private var selectedStatus: SeekerGigStatus = .saved
    @State private var selectedGig: Gig?
    
    private var currentGigs: [Gig] {
        viewModel.gigs(for: selectedStatus)
    }

    init() {
        _viewModel = StateObject(wrappedValue: SeekerGigsViewModel(backend: Back4AppService(), seekerId: nil))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(SeekerGigStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    if viewModel.isLoading {
                        ProgressView("Loading Gigs...")
                    } else if let errorMessage = viewModel.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    } else if currentGigs.isEmpty {
                        Text("You have no \(selectedStatus.rawValue.lowercased()) gigs.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        ForEach(currentGigs) { gig in
                            Button(action: {
                                selectedGig = gig
                            }) {
                                HStack {
                                    Image(systemName: gig.gigType == "immediate" ? "hourglass" : "hammer")
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading) {
                                        Text(gig.title)
                                            .font(.headline)
                                        Text("Status: \(gig.status.capitalized)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("$\(gig.gigBudgetCents / 100)")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("My Gigs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshGigs) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.updateBackend(appState.backend)
                viewModel.updateSeekerId(appState.backend.currentUserId)
                refreshGigs()
            }
            .sheet(item: $selectedGig) { gig in
                // This view needs to be defined elsewhere in your project.
                // SeekerGigDetailsView(gig: gig).environmentObject(appState)
                Text("Gig Details for \(gig.title)").font(.title)
            }
        }
    }

    private func refreshGigs() {
        Task { await viewModel.loadGigs() }
    }
}

#Preview {
    SeekerGigsView().environmentObject(AppState(backend: Back4AppService()))
}
