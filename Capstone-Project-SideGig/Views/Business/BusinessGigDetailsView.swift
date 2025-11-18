//
//  BusinessGigDetailsView.swift
//  Capstone-Project-SideGig
//
//  Created by GitHub Copilot on 11/16/25.
//

import SwiftUI

struct BusinessGigDetailsView: View {
    let gig: Gig

    var body: some View {
        VStack(spacing: 16) {
            GigDetailsView(gig: gig)

            // Businesses can manage the gig (placeholder actions)
            Button("Edit Gig") {
                // Implement edit flow later
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding()
        .navigationTitle("Gig")
    }
}

#Preview {
    let sample = Gig(id: "g1", businessId: "b1", assignedSeekerId: nil, title: "Test", description: "Test", gigType: "immediate", payType: "flat-rate", gigBudgetCents: 1000, materialsBudgetCents: 0, status: "open", latitude: 0, longitude: 0, createdAt: Date(), agreementId: nil, receiptImageUrl: nil, isEscrowFunded: false)
    BusinessGigDetailsView(gig: sample)
}
