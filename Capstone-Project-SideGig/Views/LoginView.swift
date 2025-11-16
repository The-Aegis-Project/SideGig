//
//  LoginView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var didAttemptSubmit: Bool = false
    @State private var showResetSheet: Bool = false
    @State private var resetEmail: String = ""
    @State private var resetMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text(isSignUp ? "Create account" : "Welcome back").font(.largeTitle).bold()
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
                Text(error).foregroundColor(.red)
            }

            Button("Forgot Password?") {
                // Prefill with current email if available
                resetEmail = email
                resetMessage = nil
                showResetSheet = true
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .trailing)

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

            Button(isSignUp ? "Have an account? Sign In" : "New here? Create an account") {
                isSignUp.toggle()
            }
            .padding(.top, 8)
            // SSO placeholders
            VStack(spacing: 8) {
                Button(action: signInWithApple) {
                    HStack { Image(systemName: "applelogo") ; Text("Sign in with Apple") }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button(action: signInWithGoogle) {
                    HStack { Image(systemName: "globe") ; Text("Sign in with Google") }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.white)
                        .foregroundColor(.primary)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding()
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
                if isSignUp {
                    try await appState.backend.signUp(email: email, password: password)
                } else {
                    try await appState.backend.signIn(email: email, password: password)
                }
                if let userId = appState.backend.currentUserId {
                    await appState.handleSignedIn(userId: userId)
                }
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

    private var isFormValid: Bool { isEmailValid && isPasswordValid }

    // MARK: - SSO placeholders
    private func signInWithApple() {
        Task { @MainActor in
            do {
                try await appState.backend.signInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithGoogle() {
        Task { @MainActor in
            do {
                try await appState.backend.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState(backend: Back4AppService()))
}
