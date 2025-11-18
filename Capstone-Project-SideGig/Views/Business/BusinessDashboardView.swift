import SwiftUI

struct BusinessDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var gigs: [Gig] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var applicantCounts: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            List {
                if isLoading { ProgressView().frame(maxWidth: .infinity) }
                if let msg = errorMessage { Text(msg).foregroundColor(.red) }

                ForEach(gigs) { gig in
                    NavigationLink(destination: BusinessGigDetailsView(gig: gig)) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text(gig.title).font(.headline)
                                Text(gig.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                                HStack {
                                    Text(gig.status.capitalized).font(.caption)
                                    Spacer()
                                    Text(String(format: "$%.2f", Double(gig.gigBudgetCents)/100.0)).font(.caption).bold()
                                }
                            }

                            Spacer()

                            // Applicant count badge
                            let count = applicantCounts[gig.id] ?? 0
                            ZStack {
                                Circle().fill(count > 0 ? Color.accentColor : Color.gray.opacity(0.2)).frame(width: 36, height: 36)
                                Text("\(count)")
                                    .foregroundColor(count > 0 ? .white : .primary)
                                    .font(.caption).bold()
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        NavigationLink(destination: ApplicantsListView(gig: gig)) {
                            Label("Applicants", systemImage: "person.3")
                        }
                    }
                }
            }
            .navigationTitle("My Gigs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: PostGigView()) { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refresh) { Image(systemName: "arrow.clockwise") }
                }
            }
            .onAppear { Task { await loadGigs() } }
        }
    }

    private func loadGigs() async {
        guard let businessId = appState.backend.currentUserId else { errorMessage = "Sign in as a business"; return }
        isLoading = true; errorMessage = nil
        do {
            gigs = try await appState.backend.fetchGigsForBusiness(businessId: businessId)
            // Populate applicant counts for each gig (lightweight, ok for small lists)
            applicantCounts = [:]
            for gig in gigs {
                Task {
                    do {
                        let apps = try await appState.backend.fetchApplicants(for: gig.id)
                        // update on main actor
                        await MainActor.run { applicantCounts[gig.id] = apps.count }
                    } catch {
                        await MainActor.run { applicantCounts[gig.id] = 0 }
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func refresh() { Task { await loadGigs() } }
}

#Preview {
    BusinessDashboardView().environmentObject(AppState(backend: Back4AppService()))
}
