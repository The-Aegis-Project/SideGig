//
//  GigDetailsView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI

struct GigDetailsView: View {
    let gig: Gig

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(gig.title).font(.title2).bold()
                    Text(gig.description).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Text(gig.payType == "hourly" ? "Hourly" : "Flat")
                    .font(.caption).padding(8).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Label(gig.status.capitalized, systemImage: statusIcon)
                Spacer()
                Text(formattedPrice)
                    .font(.headline)
            }

            HStack {
                Image(systemName: "mappin.and.ellipse")
                Text(String(format: "%.4f, %.4f", gig.latitude, gig.longitude)).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(gig.createdAt, style: .date).font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private var formattedPrice: String {
        let cents = gig.gigBudgetCents
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    private var statusIcon: String {
        switch gig.status {
        case "open": return "clock"
        case "assigned": return "person.crop.circle.badge.checkmark"
        case "active": return "play.circle"
        case "complete": return "checkmark.seal"
        case "cancelled": return "xmark.octagon"
        default: return "questionmark"
        }
    }
}

#Preview {
    let sample = Gig(
        id: "g1",
        businessId: "b1",
        assignedSeekerId: nil,
        title: "Clean up backyard",
        description: "Rake leaves and remove debris",
        gigType: "immediate",
        payType: "flat-rate",
        gigBudgetCents: 4500,
        materialsBudgetCents: 0,
        status: "open",
        latitude: 27.7700,
        longitude: -82.6793,
        createdAt: Date(),
        agreementId: nil,
        receiptImageUrl: nil,
        isEscrowFunded: false
    )
    GigDetailsView(gig: sample)
}
