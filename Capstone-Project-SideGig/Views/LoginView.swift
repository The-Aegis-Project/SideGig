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
            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let error = errorMessage {
                Text(error).foregroundColor(.red)
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
            .disabled(isLoading)

            Button(isSignUp ? "Have an account? Sign In" : "New here? Create an account") {
                isSignUp.toggle()
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    private func submit() {
        Task { @MainActor in
            errorMessage = nil
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
}

#Preview {
    LoginView().environmentObject(AppState(backend: Back4AppService()))
}
