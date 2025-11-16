import Foundation
import ParseSwift

// Typed ParseObject for user profile stored in Back4App
struct Profile: ParseObject {
    // ParseObject required fields
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // Custom fields
    var userId: String?
    var role: String?

    init() {}

    init(userId: String, role: String) {
        self.userId = userId
        self.role = role
    }

    // Ensure the Parse class name matches the Back4App class
    static var className: String {
        "Profile"
    }
}

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
    var gigBudget: Int?
    var materialsBudget: Int?
    var status: String?
    var latitude: Double?
    var longitude: Double?
    var agreementId: String?
    var receiptImageUrl: String?
    var isEscrowFunded: Bool?

    init() {}

    static var className: String {
        "Gig"
    }
}
