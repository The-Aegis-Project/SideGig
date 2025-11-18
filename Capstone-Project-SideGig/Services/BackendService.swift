import Foundation
import AuthenticationServices

// New enum for combined sign-up profile details
enum SignUpProfileDetails {
    case seeker(fullName: String)
    case business(businessName: String, address: String, latitude: Double, longitude: Double)
    
    var role: UserRole {
        switch self {
        case .seeker: return .seeker
        case .business: return .business
        }
    }
}

/// A protocol defining the interface for the app's backend services.
/// This allows for interchangeable backend implementations (e.g., live, mock, test).
protocol BackendService {
    var isAuthenticated: Bool { get }
    var currentUserId: String? { get }

    func configure() async throws
    // Updated signUp method to include role and initial profile data
    func signUp(email: String, password: String, profileDetails: SignUpProfileDetails) async throws -> String
    
    // Updated social sign-in methods to optionally accept profile details for new users.
    // The UI should provide these details if a new user is detected during social sign-in.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, profileDetails: SignUpProfileDetails?) async throws -> String
    func signInWithGoogle(idToken: String, profileDetails: SignUpProfileDetails?) async throws -> String
    
    // Re-introducing signIn for email/password as it's used in LoginView
    func signIn(email: String, password: String) async throws -> String

    func signOut() async throws
    func requestPasswordReset(email: String) async throws
    func fetchUserRole(userId: String) async throws -> UserRole?
    // Re-introducing setUserRole for cases where a role is selected after initial sign-in,
    // but wasn't set during the sign-up process itself (e.g., existing user or social sign-in without profile details).
    func setUserRole(userId: String, role: UserRole) async throws

    // MARK: - Profile Management
    // createSeekerProfile and createBusinessProfile will now be called internally by the signUp methods
    // but are kept public for direct profile creation/updates if needed outside of initial sign-up.
    func createSeekerProfile(userId: String, fullName: String) async throws -> SeekerProfile
    func fetchSeekerProfile(userId: String) async throws -> SeekerProfile?
    func updateSeekerProfile(profile: SeekerProfile) async throws -> SeekerProfile // Use domain model for updates

    func createBusinessProfile(userId: String, businessName: String, address: String, latitude: Double, longitude: Double) async throws -> BusinessProfile
    func fetchBusinessProfile(userId: String) async throws -> BusinessProfile?
    func updateBusinessProfile(profile: BusinessProfile) async throws -> BusinessProfile // Use domain model for updates

    // MARK: - Seeker Verification
    // Placeholder for actual ID scan service integration
    func initiateSeekerIDVerification(userId: String) async throws -> URL // Returns a URL for a third-party service
    func completeSeekerIDVerification(userId: String, verificationResult: Data) async throws // Processes callback from service

    func completeSideGigBasicsQuiz(userId: String, quizScore: Int) async throws -> SeekerProfile

    // Contact verification for seekers (email or phone)
    func initiateSeekerContactVerification(userId: String, contact: String, via: String) async throws -> SeekerProfile
    func confirmSeekerContactVerification(userId: String, code: String) async throws -> SeekerProfile

    // MARK: - Business Verification
    func linkBusinessGoogleProfile(userId: String, placeId: String, businessName: String, address: String, latitude: Double, longitude: Double) async throws -> BusinessProfile
    func linkBusinessYelpProfile(userId: String, yelpId: String, businessName: String, address: String, latitude: Double, longitude: Double) async throws -> BusinessProfile
    
    func initiateBusinessMailVerification(userId: String, address: String) async throws -> BusinessProfile
    func confirmBusinessMailVerification(userId: String, code: String) async throws -> BusinessProfile

    // MARK: - Gig Management
    // MVP Features
    func fetchGigDetails(gigId: String) async throws -> Gig?
    func applyForGig(gigId: String, seekerId: String) async throws -> GigApplication

    // Optional Features
    // Updated fetchNearbyGigs to include server-side filtering parameters
    func fetchNearbyGigs(lat: Double, lng: Double, radiusMeters: Double, payType: String?, gigType: String?, status: String?) async throws -> [Gig]
    func saveGig(gigId: String, seekerId: String) async throws -> SavedGig
    func fetchSavedGigs(seekerId: String) async throws -> [Gig]

    // Create gig with currency (ISO code)
    func createGig(businessId: String, title: String, description: String, gigType: String, payType: String, gigBudgetCents: Int, materialsBudgetCents: Int, latitude: Double, longitude: Double, currency: String) async throws -> Gig

    // Save a favorite location for a business
    func saveFavoriteLocation(businessId: String, name: String?, latitude: Double, longitude: Double) async throws -> Bool
}
