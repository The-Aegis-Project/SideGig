import SwiftUI

// Lightweight message model for the chat screen
struct BusinessMessage: Identifiable, Hashable {
    enum Sender {
        case seeker
        case business
    }

    var id: String = UUID().uuidString
    var sender: Sender
    var text: String
    var createdAt: Date = Date()
    var gigId: String
    var gigTitle: String
    var seekerId: String
    var seekerName: String
}

struct BusinessMessageBubble: View {
    let message: BusinessMessage
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .foregroundColor(isOutgoing ? .white : .primary)
                    .padding(10)
                    .background(isOutgoing ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(BusinessTimeFormatter.shared.shortTimeString(from: message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(isOutgoing ? .trailing : .leading, 6)
            }
            .frame(maxWidth: 300, alignment: isOutgoing ? .trailing : .leading)

            if !isOutgoing { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// Small time formatter helper
fileprivate class BusinessTimeFormatter {
    static let shared = BusinessTimeFormatter()
    private let formatter: DateFormatter
    private init() {
        formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
    }

    func shortTimeString(from date: Date) -> String { formatter.string(from: date) }
}

struct BusinessMessageView: View {
    @EnvironmentObject var appState: AppState

    let gigId: String
    let gigTitle: String
    let seekerId: String
    let seekerName: String

    @State private var messages: [BusinessMessage] = []
    @State private var composerText: String = ""
    @State private var isSending: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with gig title and seeker name
            VStack(alignment: .leading, spacing: 2) {
                Text(gigTitle)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(seekerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .overlay(Divider(), alignment: .bottom)

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(messages) { msg in
                            BusinessMessageBubble(message: msg, isOutgoing: msg.sender == .business)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Composer
            HStack(spacing: 8) {
                TextField("Write a message…", text: $composerText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isSending)

                Button(action: sendMessage) {
                    if isSending { ProgressView().scaleEffect(0.6) }
                    else { Image(systemName: "paperplane.fill") }
                }
                .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
            .background(Color(UIColor.systemBackground).opacity(0.95))
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadThread)
    }

    // Load any existing messages (placeholder local mock)
    private func loadThread() {
        // Integration point: replace this mock with a backend call to fetch messages for the gigId/seekerId.
        
        if messages.isEmpty {
            let welcome = BusinessMessage(sender: .seeker, text: "Hi, I'm interested in this gig.", gigId: gigId, gigTitle: gigTitle, seekerId: seekerId, seekerName: seekerName)
            let reply = BusinessMessage(sender: .business, text: "Great! When are you available?", gigId: gigId, gigTitle: gigTitle, seekerId: seekerId, seekerName: seekerName)
            messages = [welcome, reply]
        }
    }

    private func sendMessage() {
        guard !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        let outgoing = BusinessMessage(sender: .business, text: composerText.trimmingCharacters(in: .whitespacesAndNewlines), gigId: gigId, gigTitle: gigTitle, seekerId: seekerId, seekerName: seekerName)

        // Optimistically append the message
        messages.append(outgoing)
        composerText = ""

        // Integration point: send to backend using appState.backend.sendMessage(...) if supported.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Simulated seeker response
            let response = BusinessMessage(sender: .seeker, text: "I can start tomorrow.", gigId: gigId, gigTitle: gigTitle, seekerId: seekerId, seekerName: seekerName)
            messages.append(response)
            isSending = false
        }
    }
}

#Preview {
    NavigationStack {
        BusinessMessageView(gigId: "g1", gigTitle: "Fix storefront awning", seekerId: "s1", seekerName: "John Doe")
            .environmentObject(AppState(backend: Back4AppService()))
    }
}
