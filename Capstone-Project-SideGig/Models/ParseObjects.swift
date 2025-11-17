import Foundation
import ParseSwift

// NOTE: The 'Profile' ParseObject appears to be redundant with SeekerProfileParse and BusinessProfileParse.
// It has been removed. If it is still needed, please re-add it or clarify its purpose.

// Typed ParseObject for Gig
struct GigParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // Fields matching DomainModels.Gig
    var businessId: String?
    var assignedSeekerId: String?
    var title: String?
    var description: String?
    var gigType: String?
    var payType: String?
    var gigBudgetCents: Int? // Changed name from 'gigBudget' to 'gigBudgetCents' to match domain model
    var materialsBudgetCents: Int? // Changed name from 'materialsBudget' to 'materialsBudgetCents' to match domain model
    var status: String?
    var location: ParseGeoPoint? // Use ParseGeoPoint for location queries
    var agreementId: String?
    var receiptImageUrl: String?
    var isEscrowFunded: Bool?

    init() {}

    static var className: String {
        "Gig"
    }
    
    // Helper to convert to the app's domain model
    func toDomainModel() -> Gig {
        return Gig(
            id: self.objectId ?? UUID().uuidString,
            businessId: self.businessId ?? "",
            assignedSeekerId: self.assignedSeekerId,
            title: self.title ?? "Untitled Gig",
            description: self.description ?? "",
            gigType: self.gigType ?? "standard",
            payType: self.payType ?? "flat-rate",
            gigBudgetCents: self.gigBudgetCents ?? 0,
            materialsBudgetCents: self.materialsBudgetCents ?? 0, // Now directly referencing
            status: self.status ?? "open",
            latitude: self.location?.latitude ?? 0.0,
            longitude: self.location?.longitude ?? 0.0,
            createdAt: self.createdAt ?? Date(),
            agreementId: self.agreementId,
            receiptImageUrl: self.receiptImageUrl,
            isEscrowFunded: self.isEscrowFunded ?? false // This should be `self.isEscrowFunded ?? false` for consistency if it's stored in Parse
        )
    }
}


// A Parse representation of a BusinessProfile
struct BusinessProfileParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // Custom fields
    var userId: String?
    var businessName: String?
    var address: String?
    var avgRating: Double?
    var location: ParseGeoPoint? // Added to match DomainModels.BusinessProfile latitude/longitude

    // --- New fields for Business Verification ---
    var isVerifiedLocal: Bool? // Combined verification status
    var verificationMethod: String? // "google", "yelp", "mail"
    var linkedProfilePlatform: String? // "Google Business Profile", "Yelp"
    var linkedProfileId: String? // e.g., Google Place ID, Yelp Business ID
    var mailVerificationCode: String? // Temporary code sent for mail verification
    var mailVerificationInitiatedAt: Date?
    var mailVerificationConfirmedAt: Date?


    init() {}

    // Init from DomainModels.BusinessProfile
    init(from domainModel: BusinessProfile) throws { // Added 'throws'
        self.objectId = domainModel.id // Use domain model's ID for Parse objectId
        self.userId = domainModel.id // Assuming userId is the same as id for profile linking
        self.businessName = domainModel.businessName
        self.address = domainModel.address
        self.location = try ParseGeoPoint(latitude: domainModel.latitude, longitude: domainModel.longitude) // Added 'try'
        
        // Map new verification fields
        self.isVerifiedLocal = domainModel.isVerifiedLocal
        self.verificationMethod = domainModel.verificationMethod
        self.linkedProfilePlatform = domainModel.linkedProfilePlatform
        self.linkedProfileId = domainModel.linkedProfileId
        self.mailVerificationCode = domainModel.mailVerificationCode
        self.mailVerificationInitiatedAt = domainModel.mailVerificationInitiatedAt
        self.mailVerificationConfirmedAt = domainModel.mailVerificationConfirmedAt
        
        self.avgRating = domainModel.avgRating
    }


    static var className: String { "BusinessProfile" }

    // Helper to convert to the app's domain model
    func toDomainModel() -> BusinessProfile {
        return BusinessProfile(
            id: self.objectId ?? self.userId ?? UUID().uuidString, // Fallback to userId if objectId is nil
            businessName: self.businessName ?? "Untitled Business",
            address: self.address ?? "",
            latitude: self.location?.latitude ?? 0.0,
            longitude: self.location?.longitude ?? 0.0,
            
            // Map new verification fields
            isVerifiedLocal: self.isVerifiedLocal ?? false,
            verificationMethod: self.verificationMethod,
            linkedProfilePlatform: self.linkedProfilePlatform,
            linkedProfileId: self.linkedProfileId,
            mailVerificationCode: self.mailVerificationCode,
            mailVerificationInitiatedAt: self.mailVerificationInitiatedAt,
            mailVerificationConfirmedAt: self.mailVerificationConfirmedAt,
            
            avgRating: self.avgRating
        )
    }
}

// A Parse representation of a SeekerProfile
struct SeekerProfileParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // Custom fields
    var userId: String?
    var fullName: String?
    var reliabilityBadgeEarned: Bool?
    var skillBadges: [String]?
    var avgRating: Double?

    // --- New fields for Seeker Verification ---
    var isIDVerified: Bool? // ID scan verification status
    var idVerificationMethod: String? // e.g., "stripe_identity", "persona"
    var idVerificationDate: Date?
    var sideGigBasicsQuizScore: Int?
    var sideGigBasicsQuizCompletedAt: Date?
    // --- Contact verification fields ---
    var isContactVerified: Bool? // Optional to allow for default value if not explicitly set
    var contactVerificationMethod: String?
    var contactVerificationInitiatedAt: Date?
    var contactVerificationConfirmedAt: Date?
    var contactVerificationCode: String?


    init() {}

    // Init from DomainModels.SeekerProfile
    init(from domainModel: SeekerProfile) {
        self.objectId = domainModel.id // Use domain model's ID for Parse objectId
        self.userId = domainModel.id // Assuming userId is the same as id for profile linking
        self.fullName = domainModel.fullName
        self.reliabilityBadgeEarned = domainModel.reliabilityBadgeEarned
        self.skillBadges = domainModel.skillBadges
        
        // Map new verification fields
        self.isIDVerified = domainModel.isIDVerified
        self.idVerificationMethod = domainModel.idVerificationMethod
        self.idVerificationDate = domainModel.idVerificationDate
        self.sideGigBasicsQuizScore = domainModel.sideGigBasicsQuizScore
        self.sideGigBasicsQuizCompletedAt = domainModel.sideGigBasicsQuizCompletedAt
        // Map contact verification fields
        self.isContactVerified = domainModel.isContactVerified // Set non-optional Bool directly
        self.contactVerificationMethod = domainModel.contactVerificationMethod
        self.contactVerificationInitiatedAt = domainModel.contactVerificationInitiatedAt
        self.contactVerificationConfirmedAt = domainModel.contactVerificationConfirmedAt
        
        self.avgRating = domainModel.avgRating
    }


    static var className: String { "SeekerProfile" }

    // Helper to convert to the app's domain model
    func toDomainModel() -> SeekerProfile {
        return SeekerProfile(
            id: self.objectId ?? self.userId ?? UUID().uuidString, // Fallback to userId if objectId is nil
            fullName: self.fullName ?? "New Seeker",
            reliabilityBadgeEarned: self.reliabilityBadgeEarned ?? false,
            skillBadges: self.skillBadges ?? [],
            
            // Map new verification fields
            isIDVerified: self.isIDVerified ?? false,
            idVerificationMethod: self.idVerificationMethod,
            idVerificationDate: self.idVerificationDate,
            sideGigBasicsQuizScore: self.sideGigBasicsQuizScore,
            sideGigBasicsQuizCompletedAt: self.sideGigBasicsQuizCompletedAt,
            // Map contact verification
            isContactVerified: self.isContactVerified ?? false, // Default to false
            contactVerificationMethod: self.contactVerificationMethod,
            contactVerificationInitiatedAt: self.contactVerificationInitiatedAt,
            contactVerificationConfirmedAt: self.contactVerificationConfirmedAt,

            avgRating: self.avgRating
        )
    }
}

// A Parse representation of an Agreement
struct AgreementParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    var gigId: String?
    var seekerId: String?
    var businessId: String?
    var agreementText: String?
    var seekerAgreedAt: Date?
    var businessAgreedAt: Date?
    
    static var className: String { "Agreement" }
}

// A Parse representation of a Review
struct ReviewParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    var gigId: String?
    var reviewerId: String?
    var revieweeId: String?
    var rating: Int?
    var comment: String?
    var awardedBadges: [String]?
    var isReported: Bool?

    static var className: String { "Review" }
}

// MARK: - New Gig-related Parse Objects

// A Parse representation of a Gig Application
struct GigApplicationParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    var gigId: String?
    var seekerId: String?
    var status: String? // "pending", "accepted", "rejected", "withdrawn"
    var appliedAt: Date?

    init() {}
    static var className: String { "GigApplication" }

    func toDomainModel() -> GigApplication {
        return GigApplication(
            id: self.objectId ?? UUID().uuidString,
            gigId: self.gigId ?? "",
            seekerId: self.seekerId ?? "",
            status: self.status ?? "pending",
            appliedAt: self.appliedAt ?? Date()
        )
    }
}

// A Parse representation of a Saved Gig
struct SavedGigParse: ParseObject {
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    var gigId: String?
    var seekerId: String?
    var savedAt: Date?

    init() {}
    static var className: String { "SavedGig" }

    func toDomainModel() -> SavedGig {
        return SavedGig(
            id: self.objectId ?? UUID().uuidString,
            gigId: self.gigId ?? "",
            seekerId: self.seekerId ?? "",
            savedAt: self.savedAt ?? Date()
        )
    }
}

