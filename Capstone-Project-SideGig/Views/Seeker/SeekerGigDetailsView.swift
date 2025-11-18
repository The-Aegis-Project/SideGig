//
//  SeekerGigDetailsView.swift
//  Capstone-Project-SideGig
//
//  Created by GitHub Copilot on 11/16/25.
//

import SwiftUI

struct SeekerGigDetailsView: View {
    @EnvironmentObject var appState: AppState
    let gig: Gig
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            GigDetailsView(gig: gig)

            if let msg = message { Text(msg).foregroundColor(.secondary).font(.caption) }

            Button(action: apply) {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text("Apply")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle("Gig")
    }

    private func apply() {
        Task { @MainActor in
            guard let seekerId = appState.backend.currentUserId else { message = "Sign in to apply"; return }
            isLoading = true
            do {
                _ = try await appState.backend.applyForGig(gigId: gig.id, seekerId: seekerId)
                message = "Application submitted"
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    let sample = Gig(id: "g1", businessId: "b1", assignedSeekerId: nil, title: "Test", description: "Test", gigType: "immediate", payType: "flat-rate", gigBudgetCents: 1000, materialsBudgetCents: 0, status: "open", latitude: 0, longitude: 0, createdAt: Date(), agreementId: nil, receiptImageUrl: nil, isEscrowFunded: false)
    SeekerGigDetailsView(gig: sample).environmentObject(AppState(backend: Back4AppService()))
}
