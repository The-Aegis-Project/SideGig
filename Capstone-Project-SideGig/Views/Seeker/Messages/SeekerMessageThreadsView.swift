import SwiftUI
import Combine

@MainActor
final class SeekerMessageThreadsViewModel: ObservableObject {
    @Published var threads: [MessageThreadInfo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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

    func loadMessageThreads() async {
        guard let seekerId = seekerId else {
            errorMessage = "Seeker ID not available for messages."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            self.threads = try await backend.fetchSeekerMessageThreads(seekerId: seekerId)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct SeekerMessageThreadsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: SeekerMessageThreadsViewModel
    @State private var selectedThread: MessageThreadInfo?

    init() {
        _viewModel = StateObject(wrappedValue: SeekerMessageThreadsViewModel(backend: Back4AppService(), seekerId: nil))
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
                                    Text(thread.gigTitle)
                                        .font(.headline)
                                    Text(thread.businessName)
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
                viewModel.updateSeekerId(appState.backend.currentUserId)
                refreshThreads()
            }
            .sheet(item: $selectedThread) { thread in
                SeekerMessageView(
                    gigId: thread.gigId,
                    gigTitle: thread.gigTitle,
                    businessId: thread.businessId,
                    businessName: thread.businessName
                ).environmentObject(appState)
            }
        }
    }

    private func refreshThreads() {
        Task { await viewModel.loadMessageThreads() }
    }
}

#Preview {
    SeekerMessageThreadsView().environmentObject(AppState(backend: Back4AppService()))
}
