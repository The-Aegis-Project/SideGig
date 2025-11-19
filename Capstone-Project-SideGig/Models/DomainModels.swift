import Foundation
import ParseSwift

// MARK: - User & Profile Models

// Moved from Back4AppService.swift
struct SideGigUser: ParseUser, Sendable {
    // These are required by ParseUser
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // These are the default properties you get with a ParseUser
    var username: String?
    var password: String?
    var email: String?
    var emailVerified: Bool?
    var authData: [String : [String : String]?]?

    // Your custom properties
    var role: String?
    var fullName: String?
}

// Moved from BackendService.swift
enum SignUpProfileDetails: Sendable {
    case seeker(fullName: String)
    case business(businessName: String, address: String, latitude: Double, longitude: Double)
    
    var role: UserRole {
        switch self {
        case .seeker: return .seeker
        case .business: return .business
        }
    }
}

struct BusinessProfile: Identifiable, Codable, Hashable {
    var id: String // userId link
    var businessName: String
    var address: String
    var latitude: Double
    var longitude: Double
    
    // --- New fields for Business Verification ---
    var isVerifiedLocal: Bool // Combined verification status
    var verificationMethod: String? // "google", "yelp", "mail"
    var linkedProfilePlatform: String? // "Google Business Profile", "Yelp"
    var linkedProfileId: String? // e.g., Google Place ID, Yelp Business ID
    var mailVerificationCode: String? // Temporary code sent for mail verification
    var mailVerificationInitiatedAt: Date?
    var mailVerificationConfirmedAt: Date?
    // --- End New fields ---

    var avgRating: Double?
}

struct SeekerProfile: Identifiable, Codable, Hashable {
    var id: String // userId link
    var fullName: String
    var reliabilityBadgeEarned: Bool
    var skillBadges: [String]
    
    // --- New fields for Seeker Verification ---
    var isIDVerified: Bool // ID scan verification status
    var idVerificationMethod: String? // e.g., "stripe_identity", "persona"
    var idVerificationDate: Date?
    var sideGigBasicsQuizScore: Int?
    var sideGigBasicsQuizCompletedAt: Date?
    // --- Contact verification fields ---
    var isContactVerified: Bool // Changed to non-optional as it's often a base state
    var contactVerificationMethod: String?
    var contactVerificationInitiatedAt: Date?
    var contactVerificationConfirmedAt: Date?
    // --- End New fields ---

    var avgRating: Double?
}

// MARK: - Gig-related Models

enum SeekerGigStatus: String, CaseIterable, Identifiable {
    case saved = "Saved"
    case applied = "Applied"
    case active = "Active"
    case completed = "Completed"
    
    var id: String { self.rawValue }
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
    var currency: String // ISO currency code (e.g. "USD", "CAD")
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

struct GigApplication: Identifiable, Codable, Hashable {
    var id: String // objectId for the application
    var gigId: String
    var seekerId: String
    var status: String // e.g., "pending", "accepted", "rejected", "withdrawn"
    var appliedAt: Date
}

struct SavedGig: Identifiable, Codable, Hashable {
    var id: String // objectId for the saved gig entry
    var gigId: String
    var seekerId: String
    var savedAt: Date
}

// MARK: - Message Thread Info Models

// Renamed from SeekerMessageThreadInfo to MessageThreadInfo to remove duplication
struct MessageThreadInfo: Identifiable, Hashable, Codable {
    let id: String // This will be the gigId
    let gigId: String
    let gigTitle: String
    let businessId: String
    let businessName: String
}

struct BusinessMessageThreadInfo: Identifiable, Hashable, Codable {
    let id: String // Unique identifier for the thread (e.g., gigId_seekerId)
    let gigId: String
    let gigTitle: String
    let seekerId: String
    let seekerName: String
}
