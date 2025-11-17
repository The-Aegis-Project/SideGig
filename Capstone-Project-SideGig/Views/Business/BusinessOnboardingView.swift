//
//  BusinessOnboardingView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/XX/25.
//

import SwiftUI
import CoreLocation // Needed for latitude/longitude

struct BusinessOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var businessProfile: BusinessProfile?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showMailVerificationInput: Bool = false
    @State private var mailVerificationCodeInput: String = ""

    // State for linking profiles (simulated inputs)
    @State private var googlePlaceId: String = ""
    @State private var googleBusinessName: String = ""
    @State private var googleAddress: String = ""
    @State private var googleLatitude: String = ""
    @State private var googleLongitude: String = ""

    @State private var yelpId: String = ""
    @State private var yelpBusinessName: String = ""
    @State private var yelpAddress: String = ""
    @State private var yelpLatitude: String = ""
    @State private var yelpLongitude: String = ""
    
    @State private var selectedVerificationMethod: BusinessVerificationMethod? = nil

    enum BusinessVerificationMethod: String, CaseIterable, Identifiable {
        case google = "Google Business Profile"
        case yelp = "Yelp"
        case mail = "Mail Verification"
        
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .google: return "g.circle.fill"
            case .yelp: return "y.circle.fill" // Placeholder, Yelp doesn't have a SF Symbol
            case .mail: return "envelope.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                
                Text("Verify Your Business")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Text("To build trust, businesses must be locally verified.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let profile = businessProfile, profile.isVerifiedLocal {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("Business is Verified!")
                            .font(.headline)
                        Text("Verification Method: \(profile.verificationMethod ?? "N/A")")
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Picker("Select Verification Method", selection: $selectedVerificationMethod) {
                    Text("Select a method").tag(nil as BusinessVerificationMethod?)
                    ForEach(BusinessVerificationMethod.allCases) { method in
                        HStack {
                            Image(systemName: method.systemImage)
                            Text(method.rawValue)
                        }
                        .tag(method as BusinessVerificationMethod?)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 0.5))
                .padding(.horizontal)
                
                Group {
                    if selectedVerificationMethod == .google {
                        googleVerificationCard
                    } else if selectedVerificationMethod == .yelp {
                        yelpVerificationCard
                    } else if selectedVerificationMethod == .mail {
                        mailVerificationCard
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
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
        .onAppear(perform: fetchBusinessProfile)
        .refreshable {
            fetchBusinessProfile()
        }
    }
    
    // MARK: - Verification Cards
    
    private var googleVerificationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Link Google Business Profile")
                .font(.headline)
            Text("Linking a verified Google Business Profile can instantly verify your local business.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Simplified input for demonstration; in a real app, this would be a Google Places search UI
            TextField("Google Place ID (e.g., ChIJVx_zB_ ...)", text: $googlePlaceId)
                .textFieldStyle(.roundedBorder)
            TextField("Business Name", text: $googleBusinessName)
                .textFieldStyle(.roundedBorder)
            TextField("Address", text: $googleAddress)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Latitude", text: $googleLatitude)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $googleLongitude)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }

            Button(action: linkGoogleProfile) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Link Google Profile")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading || googlePlaceId.isEmpty || googleBusinessName.isEmpty || googleAddress.isEmpty || googleLatitude.isEmpty || googleLongitude.isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var yelpVerificationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Link Yelp Profile")
                .font(.headline)
            Text("Linking a verified Yelp Business Profile can instantly verify your local business.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Simplified input for demonstration
            TextField("Yelp Business ID", text: $yelpId)
                .textFieldStyle(.roundedBorder)
            TextField("Business Name", text: $yelpBusinessName)
                .textFieldStyle(.roundedBorder)
            TextField("Address", text: $yelpAddress)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Latitude", text: $yelpLatitude)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $yelpLongitude)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }

            Button(action: linkYelpProfile) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Link Yelp Profile")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red) // Yelp-like color
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading || yelpId.isEmpty || yelpBusinessName.isEmpty || yelpAddress.isEmpty || yelpLatitude.isEmpty || yelpLongitude.isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var mailVerificationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mail Verification")
                .font(.headline)
            Text("We'll send a verification code to your business address.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if showMailVerificationInput {
                Text("Address: \(businessProfile?.address ?? "N/A")")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                TextField("Enter 6-digit code", text: $mailVerificationCodeInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .limitText($mailVerificationCodeInput, limit: 6) // Corrected usage of custom modifier
                
                Button(action: confirmMailVerification) {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text("Confirm Mail Code")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading || mailVerificationCodeInput.count != 6)
            } else {
                Button(action: initiateMailVerification) {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        }
                        Text("Request Mail Verification Code")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading || businessProfile?.address == nil || businessProfile!.address.isEmpty)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    private func fetchBusinessProfile() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId else {
                errorMessage = "User not found. Please sign in again."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                businessProfile = try await appState.backend.fetchBusinessProfile(userId: userId)
                
                // Pre-fill for Google/Yelp if available from existing profile
                if let profile = businessProfile {
                    googleBusinessName = profile.businessName
                    googleAddress = profile.address
                    googleLatitude = "\(profile.latitude)"
                    googleLongitude = "\(profile.longitude)"
                    
                    yelpBusinessName = profile.businessName
                    yelpAddress = profile.address
                    yelpLatitude = "\(profile.latitude)"
                    yelpLongitude = "\(profile.longitude)"
                    
                    if profile.mailVerificationCode != nil && profile.mailVerificationConfirmedAt == nil {
                        showMailVerificationInput = true
                    } else {
                        showMailVerificationInput = false // Hide if already confirmed or not initiated
                    }
                }
                
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func linkGoogleProfile() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId,
                  let latitude = Double(googleLatitude),
                  let longitude = Double(googleLongitude) else {
                errorMessage = "User or valid location data not found."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                _ = try await appState.backend.linkBusinessGoogleProfile(
                    userId: userId,
                    placeId: googlePlaceId,
                    businessName: googleBusinessName,
                    address: googleAddress,
                    latitude: latitude,
                    longitude: longitude
                )
                await appState.bootstrap() // Refresh app state and re-fetch profile
                fetchBusinessProfile()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func linkYelpProfile() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId,
                  let latitude = Double(yelpLatitude),
                  let longitude = Double(yelpLongitude) else {
                errorMessage = "User or valid location data not found."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                _ = try await appState.backend.linkBusinessYelpProfile(
                    userId: userId,
                    yelpId: yelpId,
                    businessName: yelpBusinessName,
                    address: yelpAddress,
                    latitude: latitude,
                    longitude: longitude
                )
                await appState.bootstrap() // Refresh app state and re-fetch profile
                fetchBusinessProfile()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func initiateMailVerification() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId,
                  let address = businessProfile?.address, !address.isEmpty else {
                errorMessage = "User or business address not found. Please ensure your profile has an address."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                _ = try await appState.backend.initiateBusinessMailVerification(userId: userId, address: address)
                showMailVerificationInput = true
                await appState.bootstrap()
                fetchBusinessProfile() // Refresh profile to get updated verification status/code info
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func confirmMailVerification() {
        Task { @MainActor in
            guard let userId = appState.backend.currentUserId else {
                errorMessage = "User not found. Please sign in again."
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                _ = try await appState.backend.confirmBusinessMailVerification(userId: userId, code: mailVerificationCodeInput)
                showMailVerificationInput = false // Hide input on success
                mailVerificationCodeInput = "" // Clear input
                await appState.bootstrap()
                fetchBusinessProfile() // Refresh profile to show verified status
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Custom View Modifier for Text Field Limit

struct TextLimitModifier: ViewModifier {
    @Binding var value: String
    var limit: Int

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in // Updated onChange closure to include oldValue
                if newValue.count > limit {
                    value = String(newValue.prefix(limit))
                }
            }
    }
}

extension View {
    func limitText(_ value: Binding<String>, limit: Int) -> some View {
        self.modifier(TextLimitModifier(value: value, limit: limit))
    }
}

#Preview {
    BusinessOnboardingView()
        .environmentObject(AppState(backend: Back4AppService()))
}
