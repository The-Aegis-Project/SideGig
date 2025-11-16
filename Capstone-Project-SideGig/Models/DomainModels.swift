//
//  BusinessProfile.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//


import Foundation

struct BusinessProfile: Identifiable, Codable, Hashable {
    var id: String // userId link
    var businessName: String
    var address: String
    var latitude: Double
    var longitude: Double
    var isVerifiedLocal: Bool
    var verificationMethod: String? // "google", "yelp", or "mail"
    var avgRating: Double?
}

struct SeekerProfile: Identifiable, Codable, Hashable {
    var id: String // userId link
    var fullName: String
    var reliabilityBadgeEarned: Bool
    var skillBadges: [String]
    var avgRating: Double?
}

struct Gig: Identifiable, Codable, Hashable {
    var id: String // gigId
    var businessId: String
    var assignedSeekerId: String?
    var title: String
    var description: String
    var gigType: String // "immediate" or "project"
    var payType: String // "hourly" or "flat-rate"
    var gigBudgetCents: Int
    var materialsBudgetCents: Int
    var status: String // "open", "assigned", "active", "pending_approval", "complete", "cancelled"
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var agreementId: String?
    var receiptImageUrl: String?
    var isEscrowFunded: Bool
}

struct Agreement: Identifiable, Codable, Hashable {
    var id: String // agreementId
    var gigId: String
    var seekerId: String
    var businessId: String
    var agreementText: String
    var seekerAgreedAt: Date?
    var businessAgreedAt: Date?
}

struct Review: Identifiable, Codable, Hashable {
    var id: String
    var gigId: String
    var reviewerId: String
    var revieweeId: String
    var rating: Int
    var comment: String?
    var awardedBadges: [String]?
    var isReported: Bool
}

struct Transaction: Identifiable, Codable, Hashable {
    var id: String
    var gigId: String
    var payerId: String
    var payeeId: String
    var amountCents: Int
    var type: String // "escrow_funding", "payment_release", "materials_reimbursement"
    var status: String // "pending", "complete", "failed"
    var createdAt: Date
    var appFeeCents: Int?
}
