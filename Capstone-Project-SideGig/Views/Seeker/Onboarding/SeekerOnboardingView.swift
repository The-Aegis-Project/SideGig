//
//  SeekerOnboardingView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/16/25.
//

import SwiftUI

struct SeekerOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var wantsIDVerification: Bool = true

    // Contact verification
    @State private var contactMethod: String = "email" // "email" or "phone"
    @State private var phoneNumber: String = ""
    @State private var code: String = ""
    @State private var codeSent: Bool = false
    @State private var contactVerified: Bool = false

    // Quiz / agreements
    @State private var agreeToPrivacy: Bool = false
    @State private var agreeToTerms: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Verify Your Identity")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
            
            Text("To ensure safety, seekers should complete verification.\nYou may skip ID verification, but you'll remain unverified to businesses.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Toggle(isOn: $wantsIDVerification) {
                    VStack(alignment: .leading) {
                        Text("Secure ID Scan")
                            .font(.headline)
                        Text("Optional: scan a driver's license or passport to receive a verified badge.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Verification")
                        .font(.headline)
                    Text("We will send a verification code to confirm you are a real person.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Method", selection: $contactMethod) {
                        Text("Email").tag("email")
                        Text("Phone").tag("phone")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if contactMethod == "phone" {
                        TextField("Phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack {
                        Button(action: sendContactCode) {
                            Text(codeSent ? "Resend Code" : "Send Verification Code")
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if codeSent {
                            TextField("Enter code", text: $code)
                                .keyboardType(.numberPad)
                                .padding(8)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(action: verifyContactCode) {
                                Text("Verify")
                                    .padding(8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy & Agreements")
                        .font(.headline)
                    Toggle("I agree to the Privacy Policy", isOn: $agreeToPrivacy)
                    Toggle("I agree to the Terms of Service", isOn: $agreeToTerms)
                    Text("These are required to use SideGig as a seeker.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: finishOnboarding) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Finish Onboarding")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((!agreeToPrivacy || !agreeToTerms || (!contactVerified && !codeSent)) ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading || !agreeToPrivacy || !agreeToTerms || (!contactVerified && !codeSent))
            .padding(.horizontal)
            
            Button("Back to Login") {
                Task {
                    await appState.signOut()
                }
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 32)
        }
        .padding()
    }
    
    private func startVerification() {
        // Deprecated - kept for backward compatibility. Use finishOnboarding instead.
    }

    private func sendContactCode() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId else {
                errorMessage = "User not found. Please sign in again."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                let contact = contactMethod == "phone" ? phoneNumber : "account_email"
                _ = try await appState.backend.initiateSeekerContactVerification(userId: userId, contact: contact, via: contactMethod)
                codeSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func verifyContactCode() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId else {
                errorMessage = "User not found. Please sign in again."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                let updated = try await appState.backend.confirmSeekerContactVerification(userId: userId, code: code)
                contactVerified = updated.isContactVerified
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func finishOnboarding() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId else {
                errorMessage = "User not found. Please sign in again."
                return
            }

            // Must agree to privacy and terms
            guard agreeToPrivacy && agreeToTerms else {
                errorMessage = "You must accept the Privacy Policy and Terms to continue."
                return
            }

            // Contact must be verified
            if !contactVerified {
                errorMessage = "Please verify your contact (email or phone) before continuing."
                return
            }

            isLoading = true
            errorMessage = nil

            do {
                // If user opted in for ID verification, initiate it (this may open a web flow in real app)
                if wantsIDVerification {
                    let verificationURL = try await appState.backend.initiateSeekerIDVerification(userId: userId)
                    print("Verification URL: \(verificationURL)")
                    // In this simplified flow we won't open a web view; the actual ID verification
                    // should be completed via the third-party service and then confirmed via webhook.
                    // If you have an immediate result, you can call `completeSeekerIDVerification` here.
                }

                // Compute a basic quiz score (100 if both agreements accepted)
                let quizScore = (agreeToPrivacy && agreeToTerms) ? 100 : 0
                _ = try await appState.backend.completeSideGigBasicsQuiz(userId: userId, quizScore: quizScore)

                // Refresh app state to route user appropriately
                await appState.bootstrap()
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}


struct VerificationStepCard: View {
    let stepNumber: String
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stepNumber). \(title)")
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SeekerOnboardingView()
        .environmentObject(AppState(backend: Back4AppService()))
}
