import Foundation
import ParseSwift

protocol BackendService {
    var isAuthenticated: Bool { get }
    var currentUserId: String? { get }
    func configure() async throws
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() async throws
    func fetchUserRole(userId: String) async throws -> UserRole?
    func setUserRole(userId: String, role: UserRole) async throws
    func fetchNearbyGigs(lat: Double, lng: Double, radiusMeters: Double) async throws -> [Gig]
    // Request a password reset email for the given address. Implementations may
    // integrate with the backend provider to send a reset link or temporary code.
    func requestPasswordReset(email: String) async throws
    // SSO sign-in stubs for external providers. Implementations should wire
    // to Apple/Google sign-in flows when available.
    func signInWithApple() async throws
    func signInWithGoogle() async throws
}

final class Back4AppService: BackendService {
    private(set) var isAuthenticated: Bool = false
    private(set) var currentUserId: String? = nil

    init() {}

    func configure() async throws {
        // Ensure Back4App keys exist in Info.plist (populated via Keys.xcconfig)
        guard
            Bundle.main.object(forInfoDictionaryKey: "BACK4APP_APPLICATION_ID") as? String != nil,
            Bundle.main.object(forInfoDictionaryKey: "BACK4APP_CLIENT_KEY") as? String != nil,
            URL(string: "https://parseapi.back4app.com") != nil
        else {
            throw NSError(domain: "Config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Back4App keys in Info.plist or invalid URL"])
        }

        // ParseSwift should be initialized early in App lifecycle (App.init()).
        // We expect initialization to have already happened there. If you see
        // missing-key warnings, ensure `Keys.xcconfig` is assigned to the
        // active build configuration and Info.plist contains the substituted keys.

        // Restore session if available using the typed AppUser
        if let user = AppUser.current {
            self.isAuthenticated = true
            self.currentUserId = user.objectId
        } else {
            self.isAuthenticated = false
            self.currentUserId = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        let user = try await AppUser.login(username: email, password: password)
        self.isAuthenticated = true
        self.currentUserId = user.objectId
    }

    func signUp(email: String, password: String) async throws {
        var user = AppUser()
        user.username = email
        user.email = email
        user.password = password
        let registered = try await user.signup()
        self.isAuthenticated = true
        self.currentUserId = registered.objectId
    }

    func signOut() async throws {
        try await AppUser.logout()
        self.isAuthenticated = false
        self.currentUserId = nil
    }

    func fetchUserRole(userId: String) async throws -> UserRole? {
        // Query typed Profile objects for the given userId
        let query = Profile.query(
            // Where userId == provided id
            // ParseSwift provides an operator-based query DSL; this builds a typed query.
            "userId" == userId
        )

        if let profile = try? await query.first() {
            if let roleString = profile.role {
                return UserRole(rawValue: roleString)
            }
        }
        return nil
    }

    func setUserRole(userId: String, role: UserRole) async throws {
        // Try to find an existing Profile for this user
        let query = Profile.query("userId" == userId)
        if var existing = try? await query.first() {
            existing.role = role.rawValue
            _ = try await existing.save()
        } else {
            let profile = Profile(userId: userId, role: role.rawValue)
            _ = try await profile.save()
        }
    }

    func fetchNearbyGigs(lat: Double, lng: Double, radiusMeters: Double) async throws -> [Gig] {
        // Simple approach: query open gigs and filter by distance locally.
        // (Back4App may store a GeoPoint or separate lat/lng fields; here we assume numeric `latitude`/`longitude` fields exist.)
        let query = GigParse.query("status" == "open")
        let results = try await query.find()

        // Haversine distance filter
        func distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
            let toRad = Double.pi / 180
            let dLat = (lat2 - lat1) * toRad
            let dLon = (lon2 - lon1) * toRad
            let a = sin(dLat/2) * sin(dLat/2) + cos(lat1*toRad) * cos(lat2*toRad) * sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            let earth = 6371000.0 // meters
            return earth * c
        }

        let filtered = results.compactMap { obj -> Gig? in
            guard
                let objectId = obj.objectId,
                let businessId = obj.businessId,
                let title = obj.title,
                let description = obj.description,
                let gigType = obj.gigType,
                let payType = obj.payType,
                let gigBudget = obj.gigBudget,
                let materialsBudget = obj.materialsBudget,
                let status = obj.status,
                let latitudeVal = obj.latitude,
                let longitudeVal = obj.longitude,
                let createdAt = obj.createdAt
            else { return nil }

            let d = distanceMeters(lat1: lat, lon1: lng, lat2: latitudeVal, lon2: longitudeVal)
            if d > radiusMeters { return nil }

            return Gig(
                id: objectId,
                businessId: businessId,
                assignedSeekerId: obj.assignedSeekerId,
                title: title,
                description: description,
                gigType: gigType,
                payType: payType,
                gigBudgetCents: gigBudget,
                materialsBudgetCents: materialsBudget,
                status: status,
                latitude: latitudeVal,
                longitude: longitudeVal,
                createdAt: createdAt,
                agreementId: obj.agreementId,
                receiptImageUrl: obj.receiptImageUrl,
                isEscrowFunded: obj.isEscrowFunded ?? false
            )
        }

        return filtered
    }

    func requestPasswordReset(email: String) async throws {
        // Back4App / ParseSwift does not provide a typed async helper in this
        // minimal example. Replace this stub with a real endpoint call when
        // integrating with your backend or Parse Cloud Function.
        // For now, act as a no-op to simulate success.
        return
    }

    func signInWithApple() async throws {
        // Placeholder stub. Implement ASAuthorizationAppleIDProvider flow in
        // the app and exchange credential with the backend as needed.
        throw NSError(domain: "SSO", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sign in with Apple not implemented yet"]) 
    }

    func signInWithGoogle() async throws {
        // Placeholder stub. Integrate Google Sign-In SDK and exchange tokens
        // with your backend implementation.
        throw NSError(domain: "SSO", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sign in with Google not implemented yet"]) 
    }

    // MARK: - Mapping
    // NOTE: `PFObject` was part of the Parse ObjC SDK. When migrating to ParseSwift,
    // implement a typed ParseObject-backed `Gig` and provide mapping here.
    // The old `mapGig(_:)` helper that referenced `PFObject` was removed.
}

// Minimal typed ParseUser for ParseSwift usage.
// Consider moving this to `Models/` and expanding fields as needed.
struct AppUser: ParseUser {
    var emailVerified: Bool?
    
    var authData: [String : [String : String]?]?
    
    // Required Parse fields
    var objectId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var ACL: ParseACL?
    var originalData: Data?

    // Standard user fields
    var username: String?
    var email: String?
    var password: String?

    // Convenience initializer
    init() {}
}
