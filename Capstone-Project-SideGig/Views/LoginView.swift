//
//  LoginView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI
import AuthenticationServices
#if canImport(GoogleSignIn)
import GoogleSignIn // Import GoogleSignIn
import GoogleSignInSwift // Import GoogleSignInSwift for GIDSignInButton if needed
#endif

// A helper to wrap the UIKit-based ASAuthorizationController
class SignInWithAppleCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var continuation: CheckedContinuation<ASAuthorization, Error>?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the main window of the app
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return keyWindow!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // If the user cancels, it's not a real error we need to show.
        // The continuation will be cancelled when the scope exits.
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            return
        }
        continuation?.resume(throwing: error)
    }
}


struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var selectedRole: UserRole = .seeker
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var didAttemptSubmit: Bool = false
    @State private var showResetSheet: Bool = false
    @State private var resetEmail: String = ""
    @State private var resetMessage: String?

    // Coordinator for the Sign In with Apple flow
    @State private var signInWithAppleCoordinator: SignInWithAppleCoordinator?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(isSignUp ? "Create Your Account" : "Welcome back").font(.largeTitle).bold()
                
                // Full Name field - only show during sign-up
                if isSignUp {
                    TextField("Full Name", text: $fullName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    if (!isFullNameValid && (didAttemptSubmit || !fullName.isEmpty)) {
                        Text("Full name is required")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if (!isEmailValid && (didAttemptSubmit || !email.isEmpty)) {
                    Text("Please enter a valid email address")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if (!isPasswordValid && (didAttemptSubmit || !password.isEmpty)) {
                    Text("Password is required")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                // Role selector - only show during sign-up
                if isSignUp {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I am a...").font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            Button(action: { selectedRole = .seeker }) {
                                Text("Seeker")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedRole == .seeker ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(selectedRole == .seeker ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            Button(action: { selectedRole = .business }) {
                                Text("Business")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedRole == .business ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(selectedRole == .business ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Forgot password - only show during sign-in
                if !isSignUp {
                    Button("Forgot Password?") {
                        // Prefill with current email if available
                        resetEmail = email
                        resetMessage = nil
                        showResetSheet = true
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

            Button(action: submit) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text(isSignUp ? "Sign Up" : "Sign In")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading || !isFormValid)

            Button(isSignUp ? "Already have an account? Log in" : "New here? Create an account") {
                isSignUp.toggle()
                didAttemptSubmit = false
                errorMessage = nil
            }
            .padding(.top, 8)
            
            // SSO section - only show for sign-in or if user wants social sign-up
            if !isSignUp { // Changed from `if !isSignUp` to always show SSO buttons.
                           // The prompt to choose role for social sign-in would ideally be handled
                           // by the backend if the user is new and no profileDetails are provided.
                           // For now, these buttons will lead to sign-in or sign-up depending on existing user state.
                Text("Or sign up with").font(.caption).foregroundColor(.secondary).padding(.vertical, 8)
                
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button(action: signInWithGoogle) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Google")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.white)
                            .foregroundColor(.primary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        }
                        
                        Button(action: handleAppleSignInButton) {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Apple")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "person.crop.circle")
                                Text("Facebook")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.white)
                            .foregroundColor(.primary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "briefcase")
                                Text("LinkedIn")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.white)
                            .foregroundColor(.primary)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        }
                    }
                }
                .padding(.top, 8)
            }
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showResetSheet) {
            VStack(spacing: 12) {
                Text("Reset password").font(.headline)
                TextField("Email", text: $resetEmail)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let msg = resetMessage {
                    Text(msg).font(.caption).foregroundColor(.gray)
                }

                HStack {
                    Button("Cancel") { showResetSheet = false }
                    Spacer()
                    Button("Send Reset") {
                        Task { @MainActor in
                            do {
                                try await appState.backend.requestPasswordReset(email: resetEmail)
                                resetMessage = "If that address exists, a reset email was sent."
                            } catch {
                                resetMessage = error.localizedDescription
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .padding()
        }
    }

    private func submit() {
        Task { @MainActor in
            didAttemptSubmit = true
            errorMessage = nil
            guard isFormValid else {
                errorMessage = "Fix validation errors before continuing"
                return
            }
            isLoading = true
            do {
                let userId: String
                if isSignUp {
                    let profileDetails: SignUpProfileDetails
                    switch selectedRole {
                    case .seeker:
                        profileDetails = .seeker(fullName: fullName)
                    case .business:
                        // Placeholder values as LoginView doesn't collect these details.
                        // BusinessOnboardingView is expected to prompt for and update these.
                        profileDetails = .business(businessName: fullName, address: "N/A", latitude: 0.0, longitude: 0.0)
                    }
                    userId = try await appState.backend.signUp(email: email, password: password, profileDetails: profileDetails)
                } else {
                    userId = try await appState.backend.signIn(email: email, password: password)
                }
                await appState.handleSignedIn(userId: userId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Validation
    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: trimmed)
    }

    private var isPasswordValid: Bool {
        return !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isFullNameValid: Bool {
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isFormValid: Bool {
        // During sign-up, require full name as well
        if isSignUp {
            return isEmailValid && isPasswordValid && isFullNameValid
        }
        return isEmailValid && isPasswordValid
    }

    // MARK: - Sign in with Apple
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            do {
                switch result {
                case .success(let auth):
                    guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                        throw URLError(.badServerResponse) // A generic error
                    }
                    
                    let profileDetails: SignUpProfileDetails?
                    if isSignUp {
                        switch selectedRole {
                        case .seeker:
                            profileDetails = .seeker(fullName: credential.fullName?.givenName ?? "New Seeker") // Use Apple's name if available, else placeholder
                        case .business:
                            // Placeholder values as LoginView doesn't collect these details.
                            profileDetails = .business(businessName: credential.fullName?.givenName ?? "New Business", address: "N/A", latitude: 0.0, longitude: 0.0)
                        }
                    } else {
                        profileDetails = nil // Not signing up, just logging in or linking
                    }

                    let userId = try await appState.backend.signInWithApple(credential: credential, profileDetails: profileDetails)
                    await appState.handleSignedIn(userId: userId)

                case .failure(let error):
                    // Don't show an error if the user cancelled the flow.
                    if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                        errorMessage = error.localizedDescription
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func handleAppleSignInButton() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            // Create and retain a coordinator to receive the callback
            let coordinator = SignInWithAppleCoordinator()
            signInWithAppleCoordinator = coordinator

            do {
                let auth = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                    coordinator.continuation = continuation
                    let request = ASAuthorizationAppleIDProvider().createRequest()
                    configureAppleSignIn(request)
                    let controller = ASAuthorizationController(authorizationRequests: [request])
                    controller.delegate = coordinator
                    controller.presentationContextProvider = coordinator
                    controller.performRequests()
                }
                // Pass the successful auth to the existing handler
                handleAppleSignIn(.success(auth))
            } catch {
                handleAppleSignIn(.failure(error))
            }
            isLoading = false
        }
    }


    // MARK: - Sign in with Google
    private func signInWithGoogle() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            do {
                // Ensure GoogleSignIn is configured. Read the client ID from Info.plist keys.
#if canImport(GoogleSignIn)
                let clientID = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String
                    ?? Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String
                    ?? Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String

                guard let clientID = clientID, !clientID.isEmpty else {
                    throw GoogleSignInError.missingClientID
                }

                // Set configuration explicitly so the SDK doesn't try to read Info.plist itself
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

                guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                    .windows.first?.rootViewController else {
                    throw GoogleSignInError.noPresentingViewController
                }

                let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

                guard let idToken = signInResult.user.idToken?.tokenString else {
                    throw GoogleSignInError.noIDToken // Custom error for clarity
                }
                
                let profileDetails: SignUpProfileDetails?
                if isSignUp {
                    switch selectedRole {
                    case .seeker:
                        profileDetails = .seeker(fullName: signInResult.user.profile?.name ?? "New Seeker")
                    case .business:
                        // Placeholder values as LoginView doesn't collect these details.
                        profileDetails = .business(businessName: signInResult.user.profile?.name ?? "New Business", address: "N/A", latitude: 0.0, longitude: 0.0)
                    }
                } else {
                    profileDetails = nil // Not signing up, just logging in or linking
                }


                let userId = try await appState.backend.signInWithGoogle(idToken: idToken, profileDetails: profileDetails)
                await appState.handleSignedIn(userId: userId)
#else
                throw GoogleSignInError.sdkUnavailable
#endif

            } catch let error as GIDSignInError where error.code == .canceled {
                // User cancelled the sign-in flow, do nothing
                print("Google Sign-In cancelled.")
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    enum GoogleSignInError: Error, LocalizedError {
        case noPresentingViewController
        case noIDToken
        case missingClientID
        case sdkUnavailable

        var errorDescription: String? {
            switch self {
            case .noPresentingViewController: return "Could not find a view controller to present Google Sign-In."
            case .noIDToken: return "Could not retrieve ID token from Google Sign-In."
            case .missingClientID: return "Google Sign-In is not configured. Add your client ID to Info.plist (CLIENT_ID)."
            case .sdkUnavailable: return "Google Sign-In SDK is not available in this build."
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState(backend: Back4AppService()))
}

