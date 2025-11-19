import SwiftUI

struct ApplicantsListView: View {
    @EnvironmentObject var appState: AppState
    let gig: Gig

    @State private var applicants: [SeekerProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAssignConfirm: Bool = false
    @State private var selectedSeekerToAssign: SeekerProfile?
    @State private var assigningIds: Set<String> = []

    var body: some View {
        List {
            if isLoading { ProgressView() }
            if let msg = errorMessage { Text(msg).foregroundColor(.red) }

            ForEach(applicants, id: \.id) { seeker in
                VStack(alignment: .leading) {
                    Text(seeker.fullName).font(.headline)
                    HStack {
                        Text(seeker.isIDVerified ? "Verified" : "Unverified").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if assigningIds.contains(seeker.id) {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Button("Assign") {
                                selectedSeekerToAssign = seeker
                                showingAssignConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Applicants")
        .onAppear { Task { await loadApplicants() } }
        // Show confirmation alert when user taps Assign
        .alert("Assign Seeker", isPresented: $showingAssignConfirm, presenting: selectedSeekerToAssign) { seeker in
            Button("Confirm") { assign(seekerId: seeker.id) }
            Button("Cancel", role: .cancel) { selectedSeekerToAssign = nil }
        } message: { seeker in
            Text("Assign \(seeker.fullName) to this gig?")
        }
    }

    private func loadApplicants() async {
        isLoading = true; errorMessage = nil
        do {
            applicants = try await appState.backend.fetchApplicants(for: gig.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func assign(seekerId: String) {
        Task {
            do {
                assigningIds.insert(seekerId)
                _ = try await appState.backend.assignSeeker(seekerId: seekerId, to: gig.id)
                assigningIds.remove(seekerId)
                await loadApplicants()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ApplicantsListView(gig: Gig(id: "g1", businessId: "b1", assignedSeekerId: nil, title: "Test", description: "Test", gigType: "immediate", payType: "flat-rate", gigBudgetCents: 1000, materialsBudgetCents: 0, status: "open", latitude: 0, longitude: 0, createdAt: Date(), agreementId: nil, receiptImageUrl: nil, isEscrowFunded: false, currency: "USD")).environmentObject(AppState(backend: Back4AppService()))
}

