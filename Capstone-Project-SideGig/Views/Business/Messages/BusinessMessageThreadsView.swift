import SwiftUI
import Combine

@MainActor
final class BusinessMessageThreadsViewModel: ObservableObject {
    @Published var threads: [BusinessMessageThreadInfo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var backend: BackendService
    private var businessId: String?

    init(backend: BackendService, businessId: String?) {
        self.backend = backend
        self.businessId = businessId
    }

    func updateBackend(_ backend: BackendService) {
        self.backend = backend
    }

    func updateBusinessId(_ id: String?) {
        self.businessId = id
    }

    func loadMessageThreads() async {
        guard let businessId = businessId else {
            errorMessage = "Business ID not available for messages."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            self.threads = try await backend.fetchBusinessMessageThreads(businessId: businessId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct BusinessMessageThreadsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: BusinessMessageThreadsViewModel
    @State private var selectedThread: BusinessMessageThreadInfo?

    init() {
        _viewModel = StateObject(wrappedValue: BusinessMessageThreadsViewModel(backend: Back4AppService(), businessId: nil))
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading Messages...")
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                } else if viewModel.threads.isEmpty {
                    Text("You don't have any active message threads yet.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(viewModel.threads) { thread in
                        Button(action: {
                            selectedThread = thread
                        }) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(thread.seekerName)
                                        .font(.headline)
                                    Text(thread.gigTitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshThreads) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.updateBackend(appState.backend)
                viewModel.updateBusinessId(appState.backend.currentUserId)
                refreshThreads()
            }
            .sheet(item: $selectedThread) { thread in
                BusinessMessageView(
                    gigId: thread.gigId,
                    gigTitle: thread.gigTitle,
                    seekerId: thread.seekerId,
                    seekerName: thread.seekerName
                ).environmentObject(appState)
            }
        }
    }

    private func refreshThreads() {
        Task { await viewModel.loadMessageThreads() }
    }
}

#Preview {
    BusinessMessageThreadsView().environmentObject(AppState(backend: Back4AppService()))
}
