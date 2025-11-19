import SwiftUI

// Lightweight message model for the chat screen
struct Message: Identifiable, Hashable {
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
    var businessId: String
    var businessName: String
}

struct MessageBubble: View {
    let message: Message
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                // Show header for the first message in a thread (gig + business displayed at top of chat separately)
                Text(message.text)
                    .foregroundColor(isOutgoing ? .white : .primary)
                    .padding(10)
                    .background(isOutgoing ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(TimeFormatter.shared.shortTimeString(from: message.createdAt))
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
fileprivate class TimeFormatter {
    static let shared = TimeFormatter()
    private let formatter: DateFormatter
    private init() {
        formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
    }

    func shortTimeString(from date: Date) -> String { formatter.string(from: date) }
}

struct SeekerMessageView: View {
    @EnvironmentObject var appState: AppState

    let gigId: String
    let gigTitle: String
    let businessId: String
    let businessName: String

    @State private var messages: [Message] = []
    @State private var composerText: String = ""
    @State private var isSending: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with gig title and business name
            VStack(alignment: .leading, spacing: 2) {
                Text(gigTitle)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(businessName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    // Example verified badge indicator for businesses in header
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .opacity(0.9)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .overlay(Divider(), alignment: .bottom)

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Show a small context bar with gig/business for each message group (optional)
                        ForEach(messages) { msg in
                            MessageBubble(message: msg, isOutgoing: msg.sender == .seeker)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .onChange(of: messages.count) {
                    // scroll to bottom when new message arrives
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
        // Integration point: replace this mock with a backend call to fetch messages for the gigId/businessId.
        // Example: messages = try await appState.backend.fetchMessages(gigId: gigId)

        // For now, populate with a simple sample thread if empty
        if messages.isEmpty {
            let welcome = Message(sender: .business, text: "Hi — thanks for applying to \(gigTitle). When can you start?", gigId: gigId, gigTitle: gigTitle, businessId: businessId, businessName: businessName)
            let reply = Message(sender: .seeker, text: "Thanks — I can start tomorrow morning.", gigId: gigId, gigTitle: gigTitle, businessId: businessId, businessName: businessName)
            messages = [welcome, reply]
        }
    }

    private func sendMessage() {
        guard !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        let outgoing = Message(sender: .seeker, text: composerText.trimmingCharacters(in: .whitespacesAndNewlines), gigId: gigId, gigTitle: gigTitle, businessId: businessId, businessName: businessName)

        // Optimistically append the message
        messages.append(outgoing)
        composerText = ""

        // Integration point: send to backend using appState.backend.sendMessage(...) if supported.
        // Simulate network delay and a canned business reply for demo purposes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Simulated business response
            let response = Message(sender: .business, text: "Thanks, we'll confirm and get back to you.", gigId: gigId, gigTitle: gigTitle, businessId: businessId, businessName: businessName)
            messages.append(response)
            isSending = false
        }
    }
}

#Preview {
    NavigationStack {
        SeekerMessageView(gigId: "g1", gigTitle: "Fix storefront awning", businessId: "b1", businessName: "Corner Deli")
            .environmentObject(AppState(backend: Back4AppService()))
    }
}
