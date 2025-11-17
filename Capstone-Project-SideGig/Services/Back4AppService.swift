//
//  Back4AppService.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import Foundation
import ParseSwift
import CoreLocation
import AuthenticationServices
import GoogleSignIn

// Define a custom user object for this app.
// This is where you can add custom properties to the user, e.g. "role", "fullName", etc.
// Moved here to resolve "Cannot find 'SideGigUser' in scope" errors.
struct SideGigUser: ParseUser {
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


class Back4AppService: BackendService {
    // Your singleton instance
    static let shared = Back4AppService()

    // Read keys from the xcconfig file
    private var applicationId: String {
        return Bundle.main.object(forInfoDictionaryKey: "BACK4APP_APPLICATION_ID") as! String
    }
    private var clientKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "BACK4APP_CLIENT_KEY") as! String
    }

    // `SideGigUser.current` in ParseSwift is a concrete value; check sessionToken instead
    var isAuthenticated: Bool { !(SideGigUser.current?.sessionToken ?? "").isEmpty }
    var currentUserId: String? { SideGigUser.current?.objectId }

    func configure() async throws {
        let configuration = ParseSwift.ParseConfiguration(
            applicationId: self.applicationId,
            clientKey: self.clientKey,
            serverURL: URL(string: "https://parseapi.back4app.com")!
        )
        ParseSwift.initialize(configuration: configuration)

        // Try to restore a user session automatically
        do {
            // Check if current session token exists before trying to become
            if let sessionToken = SideGigUser.current?.sessionToken, !sessionToken.isEmpty {
                _ = try await SideGigUser().become(sessionToken: sessionToken)
            }
        } catch {
            // If it fails, that's fine, it just means no user was logged in.
            // We can clear any old keychain data to be safe.
            try? await SideGigUser.logout()
        }
    }

    // New helper method to create the appropriate profile based on SignUpProfileDetails
    private func createProfileForUser(userId: String, profileDetails: SignUpProfileDetails) async throws {
        switch profileDetails {
        case .seeker(let fullName):
            _ = try await createSeekerProfile(userId: userId, fullName: fullName)
        case .business(let businessName, let address, let latitude, let longitude):
            _ = try await createBusinessProfile(userId: userId, businessName: businessName, address: address, latitude: latitude, longitude: longitude)
        }
    }

    // UPDATED: signUp method to include role and initial profile data
    func signUp(email: String, password: String, profileDetails: SignUpProfileDetails) async throws -> String {
        var newUser = SideGigUser()
        newUser.username = email.lowercased()
        newUser.email = email.lowercased()
        newUser.password = password
        newUser.role = profileDetails.role.rawValue // Set the user's role
        
        if case let .seeker(fullName) = profileDetails {
            newUser.fullName = fullName // Set fullName for seekers directly on the user object
        }

        let savedUser = try await newUser.signup()
        guard let id = savedUser.objectId else {
            throw URLError(.cannotFindHost) // Should not happen
        }

        // Create the associated profile (SeekerProfile or BusinessProfile)
        try await createProfileForUser(userId: id, profileDetails: profileDetails)

        return id
    }

    func signIn(email: String, password: String) async throws -> String {
        let user = try await SideGigUser.login(username: email.lowercased(), password: password)
        guard let id = user.objectId else {
            throw URLError(.cannotFindHost) // Should not happen
        }
        return id
    }
    
    // UPDATED: signInWithApple to optionally accept profile details for new users
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, profileDetails: SignUpProfileDetails?) async throws -> String {
        guard let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Could not get identity token from Apple."])
        }
        
        let provider = "apple"
        let providerAuth: [String: String] = ["id": credential.user, "token": tokenString]

        var user = try await SideGigUser.login(provider, authData: providerAuth)

        // If it's a new user (role is nil) and profile details are provided, set role and create profile
        if user.role == nil, let details = profileDetails {
            user.role = details.role.rawValue
            if case let .seeker(fullName) = details {
                 user.fullName = fullName // Set fullName for seekers
            }
            user = try await user.save() // Save the updated user object with role and fullName

            try await createProfileForUser(userId: user.objectId!, profileDetails: details)
        } else if user.role == nil && profileDetails == nil {
            // This case implies a new user signed in with Apple but profileDetails were not provided by the UI.
            // To ensure the "merged sign-up" experience, we'll enforce profileDetails for new social users.
            throw ProfileError.missingProfileDetailsForNewUser
        }
        
        // If Apple provided the user's name (happens on first sign-in) and our user record
        // doesn't have a name yet, update it. This can run even if profileDetails were provided
        // if the profileDetails only contained role but not name, or to ensure consistency.
        if user.fullName == nil, let appleFullName = credential.fullName {
             let formatter = PersonNameComponentsFormatter()
             user.fullName = formatter.string(from: appleFullName)
             // Save the updated user information
             user = try await user.save()
        }

        guard let id = user.objectId else {
            throw URLError(.cannotFindHost) // Should not happen
        }
        return id
    }

    // UPDATED: signInWithGoogle to optionally accept profile details for new users
    func signInWithGoogle(idToken: String, profileDetails: SignUpProfileDetails?) async throws -> String {
        let provider = "google"
        let providerAuth: [String: String] = ["id_token": idToken]
        
        var user = try await SideGigUser.login(provider, authData: providerAuth)
        
        // If it's a new user (role is nil) and profile details are provided, set role and create profile
        if user.role == nil, let details = profileDetails {
            user.role = details.role.rawValue
            if case let .seeker(fullName) = details {
                 user.fullName = fullName // Set fullName for seekers
            }
            user = try await user.save() // Save the updated user object with role and fullName

            try await createProfileForUser(userId: user.objectId!, profileDetails: details)
        } else if user.role == nil && profileDetails == nil {
            throw ProfileError.missingProfileDetailsForNewUser
        }
        
        // Note: Google Sign-In typically provides name/email, which ParseSwift would
        // use to populate `fullName` and `email` on the `SideGigUser` initially.
        // We assume `profileDetails` would override or confirm these for new users if provided.

        guard let id = user.objectId else {
            throw URLError(.cannotFindHost) // Should not happen
        }
        return id
    }

    func signOut() async throws {
        try await SideGigUser.logout()
    }

    func requestPasswordReset(email: String) async throws {
        try await SideGigUser.passwordReset(email: email.lowercased())
    }

    func fetchUserRole(userId: String) async throws -> UserRole? {
        let user = try await SideGigUser.query().where("objectId" == userId).first()
        guard let roleString = user.role else { return nil } // Access 'role' via optional chaining
        return UserRole(rawValue: roleString)
    }

    // RE-INTRODUCED: setUserRole for setting/updating the role of an existing user.
    func setUserRole(userId: String, role: UserRole) async throws {
        // Ensure the current user is authenticated
        guard var currentUser = SideGigUser.current else {
            throw ProfileError.currentUserNotFound
        }
        
        // Double-check that the userId matches the currently authenticated user's objectId.
        // This prevents accidentally updating the wrong user's role.
        guard currentUser.objectId == userId else {
            throw ProfileError.unauthorizedRoleUpdate // Or a more specific error
        }

        currentUser.role = role.rawValue
        _ = try await currentUser.save()
    }

    // MARK: - Profile Management
    func createSeekerProfile(userId: String, fullName: String) async throws -> SeekerProfile {
        var newProfile = SeekerProfileParse()
        newProfile.userId = userId
        newProfile.fullName = fullName
        // Set initial verification status
        newProfile.isIDVerified = false
        newProfile.isContactVerified = false // Initialize new field
        newProfile.sideGigBasicsQuizScore = 0
        newProfile.reliabilityBadgeEarned = false // Initialize other fields
        newProfile.skillBadges = []
        let savedProfile = try await newProfile.save()
        return savedProfile.toDomainModel()
    }

    // Contact verification for seekers (email or SMS)
    func initiateSeekerContactVerification(userId: String, contact: String, via: String) async throws -> SeekerProfile {
        // Fetch existing Parse object
        let query = SeekerProfileParse.query().where("userId" == userId)
        guard var parseProfile = try? await query.first() else {
            throw ProfileError.profileNotFound(userId)
        }

        // Generate a random 6-digit code
        let verificationCode = String(format: "%06d", arc4random_uniform(1_000_000))

        // Store verification metadata on the Parse object
        parseProfile.contactVerificationCode = verificationCode
        parseProfile.contactVerificationMethod = via
        parseProfile.contactVerificationInitiatedAt = Date()
        parseProfile.isContactVerified = false // Reset verification status
        parseProfile.contactVerificationConfirmedAt = nil // Clear confirmed date

        // Simulate sending verification via email or SMS
        print("Sending verification code \(verificationCode) to \(contact) via \(via) for user \(userId)")

        let saved = try await parseProfile.save()
        return saved.toDomainModel()
    }

    func confirmSeekerContactVerification(userId: String, code: String) async throws -> SeekerProfile {
        let query = SeekerProfileParse.query().where("userId" == userId)
        guard var parseProfile = try? await query.first() else {
            throw ProfileError.profileNotFound(userId)
        }

        guard let stored = parseProfile.contactVerificationCode,
              let initiatedAt = parseProfile.contactVerificationInitiatedAt else {
            throw ProfileError.mailVerificationNotInitiated // Reusing for contact for now, consider new specific error
        }

        guard stored == code else {
            throw ProfileError.invalidVerificationCode
        }

        // Optional expiration (7 days)
        let expirationDate = initiatedAt.addingTimeInterval(3600 * 24 * 7)
        guard Date() < expirationDate else {
            throw ProfileError.mailVerificationCodeExpired // Reusing for contact for now
        }

        parseProfile.isContactVerified = true
        parseProfile.contactVerificationConfirmedAt = Date()
        parseProfile.contactVerificationCode = nil // Clear the code after successful verification

        let saved = try await parseProfile.save()
        return saved.toDomainModel()
    }

    func fetchSeekerProfile(userId: String) async throws -> SeekerProfile? {
        let query = SeekerProfileParse.query().where("userId" == userId)
        if let parseProfile = try? await query.first() {
            return parseProfile.toDomainModel()
        }
        return nil
    }
    
    func updateSeekerProfile(profile: SeekerProfile) async throws -> SeekerProfile {
        // Fetch existing Parse object using the profile's ID (which is the Parse objectId)
        let query = SeekerProfileParse.query().where("objectId" == profile.id)
        var parseProfile: SeekerProfileParse? = try? await query.first()
        
        if parseProfile == nil { 
            throw ProfileError.profileNotFound(profile.id)
        } else {
            var existingProfile = parseProfile! 
            // The `userId` property on `SeekerProfileParse` should be the ID of the `SideGigUser`.
            // The `profile.id` here should be the `objectId` of the `SeekerProfileParse` itself.
            // Avoid reassigning `userId` as it's typically set once on creation and links to the SideGigUser.
            existingProfile.fullName = profile.fullName
            existingProfile.reliabilityBadgeEarned = profile.reliabilityBadgeEarned
            existingProfile.skillBadges = profile.skillBadges
            existingProfile.avgRating = profile.avgRating
            existingProfile.isIDVerified = profile.isIDVerified
            existingProfile.idVerificationMethod = profile.idVerificationMethod
            existingProfile.idVerificationDate = profile.idVerificationDate
            existingProfile.sideGigBasicsQuizScore = profile.sideGigBasicsQuizScore
            existingProfile.sideGigBasicsQuizCompletedAt = profile.sideGigBasicsQuizCompletedAt
            // Map new contact verification fields
            existingProfile.isContactVerified = profile.isContactVerified
            existingProfile.contactVerificationMethod = profile.contactVerificationMethod
            existingProfile.contactVerificationInitiatedAt = profile.contactVerificationInitiatedAt
            existingProfile.contactVerificationConfirmedAt = profile.contactVerificationConfirmedAt
            parseProfile = existingProfile
        }
        
        guard let profileToSave = parseProfile else {
            throw ProfileError.invalidProfileID(profile.id)
        }
        
        let updatedParseProfile = try await profileToSave.save()
        return updatedParseProfile.toDomainModel()
    }


    func createBusinessProfile(userId: String, businessName: String, address: String, latitude: Double, longitude: Double) async throws -> BusinessProfile {
        var newProfile = BusinessProfileParse()
        newProfile.userId = userId
        newProfile.businessName = businessName
        newProfile.address = address
        newProfile.location = try ParseGeoPoint(latitude: latitude, longitude: longitude)
        // Set initial verification status
        newProfile.isVerifiedLocal = false
        let savedProfile = try await newProfile.save()
        return savedProfile.toDomainModel()
    }

    func fetchBusinessProfile(userId: String) async throws -> BusinessProfile? {
        let query = BusinessProfileParse.query().where("userId" == userId)
        if let parseProfile = try? await query.first() {
            return parseProfile.toDomainModel()
        }
        return nil
    }

    func updateBusinessProfile(profile: BusinessProfile) async throws -> BusinessProfile {
        // Fetch existing Parse object using the profile's ID (which is the Parse objectId)
        let query = BusinessProfileParse.query().where("objectId" == profile.id)
        var parseProfile: BusinessProfileParse? = try? await query.first()
        
        if parseProfile == nil { 
            throw ProfileError.profileNotFound(profile.id)
        } else {
            var existingProfile = parseProfile!
            // Avoid reassigning `userId` for the same reasons as `SeekerProfile`.
            existingProfile.businessName = profile.businessName
            existingProfile.address = profile.address
            existingProfile.avgRating = profile.avgRating
            existingProfile.location = try ParseGeoPoint(latitude: profile.latitude, longitude: profile.longitude)
            existingProfile.isVerifiedLocal = profile.isVerifiedLocal
            existingProfile.verificationMethod = profile.verificationMethod
            existingProfile.linkedProfilePlatform = profile.linkedProfilePlatform
            existingProfile.linkedProfileId = profile.linkedProfileId
            existingProfile.mailVerificationCode = profile.mailVerificationCode
            existingProfile.mailVerificationInitiatedAt = profile.mailVerificationInitiatedAt
            existingProfile.mailVerificationConfirmedAt = profile.mailVerificationConfirmedAt
            parseProfile = existingProfile
        }

        guard let profileToSave = parseProfile else {
            throw ProfileError.invalidProfileID(profile.id)
        }
        
        let updatedParseProfile = try await profileToSave.save()
        return updatedParseProfile.toDomainModel()
    }


    // MARK: - Seeker Verification
    func initiateSeekerIDVerification(userId: String) async throws -> URL {
        // In a real app, this would involve integrating with a third-party service
        // like Stripe Identity, Persona, or Onfido.
        // This function would typically create a verification session on the service's
        // backend and return a URL or client secret needed by the mobile SDK to launch the flow.
        
        // Placeholder implementation:
        print("Initiating Seeker ID verification for user: \(userId)")
        // Simulate a service that returns a verification URL
        // Replace with actual integration in production
        return URL(string: "https://example.com/id-verification-service?user=\(userId)&session=dummy-session-id")!
    }

    func completeSeekerIDVerification(userId: String, verificationResult: Data) async throws {
        // This function would process the callback/webhook result from the third-party ID verification service.
        // The `verificationResult` would contain the status of the ID check.
        // For now, we'll just simulate updating the profile.
        
        guard var currentProfile = try await fetchSeekerProfile(userId: userId) else {
            throw ProfileError.profileNotFound(userId)
        }
        
        // Simulate successful verification
        currentProfile.isIDVerified = true
        currentProfile.idVerificationMethod = "simulated_service" // Added
        currentProfile.idVerificationDate = Date() // Added
        
        _ = try await updateSeekerProfile(profile: currentProfile)
        print("Seeker ID verification completed for user: \(userId)")
    }

    func completeSideGigBasicsQuiz(userId: String, quizScore: Int) async throws -> SeekerProfile {
        guard var currentProfile = try await fetchSeekerProfile(userId: userId) else {
            throw ProfileError.profileNotFound(userId)
        }
        
        currentProfile.sideGigBasicsQuizScore = quizScore
        currentProfile.sideGigBasicsQuizCompletedAt = Date()
        
        return try await updateSeekerProfile(profile: currentProfile)
    }

    // MARK: - Business Verification
    func linkBusinessGoogleProfile(userId: String, placeId: String, businessName: String, address: String, latitude: Double, longitude: Double) async throws -> BusinessProfile {
        guard var currentProfile = try await fetchBusinessProfile(userId: userId) else {
            throw ProfileError.profileNotFound(userId)
        }
        
        currentProfile.businessName = businessName
        currentProfile.address = address
        currentProfile.latitude = latitude
        currentProfile.longitude = longitude
        currentProfile.isVerifiedLocal = true // Assuming linking a verified Google profile counts as verified
        currentProfile.verificationMethod = "google_profile"
        currentProfile.linkedProfilePlatform = "Google Business Profile"
        currentProfile.linkedProfileId = placeId
        
        return try await updateBusinessProfile(profile: currentProfile)
    }

    func linkBusinessYelpProfile(userId: String, yelpId: String, businessName: String, address: String, latitude: Double, longitude: Double) async throws -> BusinessProfile {
        guard var currentProfile = try await fetchBusinessProfile(userId: userId) else {
            throw ProfileError.profileNotFound(userId)
        }
        
        currentProfile.businessName = businessName
        currentProfile.address = address
        currentProfile.latitude = latitude
        currentProfile.longitude = longitude
        currentProfile.isVerifiedLocal = true // Assuming linking a verified Yelp profile counts as verified
        currentProfile.verificationMethod = "yelp_profile"
        currentProfile.linkedProfilePlatform = "Yelp"
        currentProfile.linkedProfileId = yelpId
        
        return try await updateBusinessProfile(profile: currentProfile)
    }
    
    func initiateBusinessMailVerification(userId: String, address: String) async throws -> BusinessProfile {
        guard var currentProfile = try await fetchBusinessProfile(userId: userId) else {
            throw ProfileError.profileNotFound(userId)
        }
        
        // Generate a random 6-digit code
        let verificationCode = String(format: "%06d", arc4random_uniform(1_000_000))
        
        // In a real application, you would send this code via physical mail to the provided address.
        // For this backend implementation, we'll store it in the profile and log it.
        print("Simulating sending mail verification code '\(verificationCode)' to address: \(address) for user: \(userId)")
        
        currentProfile.mailVerificationCode = verificationCode
        currentProfile.mailVerificationInitiatedAt = Date()
        currentProfile.isVerifiedLocal = false // Reset verification status until mail is confirmed
        currentProfile.verificationMethod = "mail" // Indicate mail verification is in progress
        
        // Also update the address if it changed during this process
        currentProfile.address = address
        
        return try await updateBusinessProfile(profile: currentProfile)
    }

    func confirmBusinessMailVerification(userId: String, code: String) async throws -> BusinessProfile {
        guard var currentProfile = try await fetchBusinessProfile(userId: userId) else {
            throw ProfileError.profileNotFound(userId)
        }
        
        guard let storedCode = currentProfile.mailVerificationCode,
              let initiatedAt = currentProfile.mailVerificationInitiatedAt else {
            throw ProfileError.mailVerificationNotInitiated
        }
        
        // Check if the code is correct
        guard storedCode == code else {
            throw ProfileError.invalidVerificationCode
        }
        
        // Optional: Add a timeout for the code
        let expirationDate = initiatedAt.addingTimeInterval(3600 * 24 * 7) // 7 days expiration
        guard Date() < expirationDate else {
            throw ProfileError.mailVerificationCodeExpired
        }
        
        currentProfile.isVerifiedLocal = true
        currentProfile.mailVerificationConfirmedAt = Date()
        currentProfile.mailVerificationCode = nil // Clear the code after successful verification
        
        return try await updateBusinessProfile(profile: currentProfile)
    }


    // MARK: - Gig Management

    // MVP Feature: Fetch Single Gig Details
    func fetchGigDetails(gigId: String) async throws -> Gig? {
        let query = GigParse.query().where("objectId" == gigId)
        // Use `try?` to get an optional result for safe conditional binding
        guard let parseGig = try? await query.first() else {
            return nil // Gig not found
        }
        return parseGig.toDomainModel()
    }

    // MVP Feature: Apply for a Gig
    func applyForGig(gigId: String, seekerId: String) async throws -> GigApplication {
        // First, check if the gig exists
        let gigQuery = GigParse.query().where("objectId" == gigId)
        let gigExists = try await gigQuery.count() > 0
        guard gigExists else {
            throw ProfileError.gigNotFound(gigId)
        }

        // Check if the seeker has already applied for this gig
        let existingApplicationQuery = GigApplicationParse.query().where("gigId" == gigId).where("seekerId" == seekerId)
        if try await existingApplicationQuery.count() > 0 {
            throw ProfileError.alreadyAppliedForGig
        }

        var newApplication = GigApplicationParse()
        newApplication.gigId = gigId
        newApplication.seekerId = seekerId
        newApplication.status = "pending" // Initial status
        newApplication.appliedAt = Date()

        let savedApplication = try await newApplication.save()
        return savedApplication.toDomainModel()
    }


    // Optional Feature: Filtering Gigs (updated function signature)
    func fetchNearbyGigs(lat: Double, lng: Double, radiusMeters: Double, payType: String?, gigType: String?, status: String?) async throws -> [Gig] {
        // NOTE: ParseSwift's geo query helpers vary between versions. To keep this
        // implementation simple and compile-safe across ParseSwift API changes,
        // this function currently performs non-geo filtered lookups with the
        // requested attribute filters. A proper geo query (e.g. withinKilometers)
        // can be added once the exact ParseSwift API version is selected.
        var query = GigParse.query()

        // Apply status filter (default to "open" if not specified)
        let gigStatus = status ?? "open"
        query = query.where("status" == gigStatus)

        if let payType = payType {
            query = query.where("payType" == payType)
        }
        if let gigType = gigType {
            query = query.where("gigType" == gigType)
        }

        let results = try await query.find()
        return results.compactMap { $0.toDomainModel() }
    }
    
    // Optional Feature: Saving/Watching Gigs
    func saveGig(gigId: String, seekerId: String) async throws -> SavedGig {
        // Check if the gig exists
        let gigQuery = GigParse.query().where("objectId" == gigId)
        let gigExists = try await gigQuery.count() > 0
        guard gigExists else {
            throw ProfileError.gigNotFound(gigId)
        }

        // Check if the gig is already saved by this seeker
        let existingSaveQuery = SavedGigParse.query().where("gigId" == gigId).where("seekerId" == seekerId)
        if try await existingSaveQuery.count() > 0 {
            throw ProfileError.gigAlreadySaved
        }

        var newSavedGig = SavedGigParse()
        newSavedGig.gigId = gigId
        newSavedGig.seekerId = seekerId
        newSavedGig.savedAt = Date()

        let savedGigEntry = try await newSavedGig.save()
        return savedGigEntry.toDomainModel()
    }

    func fetchSavedGigs(seekerId: String) async throws -> [Gig] {
        // Find all SavedGig entries for the seeker
        let savedGigsQuery = SavedGigParse.query().where("seekerId" == seekerId)
        let savedGigEntries = try await savedGigsQuery.find()

        // Extract the gigIds from the saved entries
        let gigIds = savedGigEntries.compactMap { $0.gigId }

        guard !gigIds.isEmpty else {
            return [] // No gigs saved
        }

        // Fetch the actual Gig objects using the collected gigIds.
        // `containedIn` helpers vary between ParseSwift versions; perform
        // per-id lookups which are safe and compatible.
        var resultGigs: [Gig] = []
        for id in gigIds {
            let q = GigParse.query().where("objectId" == id)
            if let parseGig = try? await q.first() {
                let g = parseGig.toDomainModel()
                resultGigs.append(g)
            }
        }

        return resultGigs
    }
    
    // Custom errors for better error handling in the app
    enum ProfileError: Error, LocalizedError {
        case currentUserNotFound
        case unauthorizedRoleUpdate
        case profileNotFound(String?) // Updated to allow optional ID
        case invalidProfileID(String?)
        case mailVerificationNotInitiated // Used for contact verification too
        case invalidVerificationCode
        case mailVerificationCodeExpired // Used for contact verification too
        case missingProfileDetailsForNewUser // New error for social sign-in requiring profile details
        case gigNotFound(String?) // New error for when a specified gig ID doesn't exist
        case alreadyAppliedForGig // New error for duplicate gig applications
        case gigAlreadySaved // New error for trying to save a gig that's already saved
        case unknownError(String)
        
        var errorDescription: String? {
            switch self {
            case .currentUserNotFound: return "Current user session not found. Please sign in again."
            case .unauthorizedRoleUpdate: return "Unauthorized role update attempt. The provided user ID does not match the current authenticated user."
            case .profileNotFound(let userId): return "User profile not found for ID: \(userId ?? "nil")."
            case .invalidProfileID(let id): return "Invalid profile ID: \(id ?? "nil"). Cannot update."
            case .mailVerificationNotInitiated: return "Verification process has not been initiated or is invalid."
            case .invalidVerificationCode: return "The provided verification code is incorrect."
            case .mailVerificationCodeExpired: return "The verification code has expired. Please initiate a new verification."
            case .missingProfileDetailsForNewUser: return "Profile details are required to complete sign-up for this new user. Please provide your role and initial profile information."
            case .gigNotFound(let gigId): return "The specified gig was not found: \(gigId ?? "nil")."
            case .alreadyAppliedForGig: return "You have already applied for this gig."
            case .gigAlreadySaved: return "This gig is already in your saved list."
            case .unknownError(let message): return "An unknown error occurred: \(message)"
            }
        }
    }
}

