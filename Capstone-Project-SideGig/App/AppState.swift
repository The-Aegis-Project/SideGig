//
//  AppState.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//


import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    enum Route: Equatable {
        case login
        case roleSelect
        case seekerOnboarding // New route for seeker onboarding/verification
        case businessOnboarding // New route for business onboarding/verification
        case seekerHome
        case businessHome
    }

    @Published var route: Route = .login
    @Published var role: UserRole? = nil
    @Published var seekerProfile: SeekerProfile? = nil // Store current user's profile
    @Published var businessProfile: BusinessProfile? = nil // Store current user's profile
    let backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    func bootstrap() async {
        do {
            try await backend.configure()
            if backend.isAuthenticated, let userId = backend.currentUserId {
                if let r = try await backend.fetchUserRole(userId: userId) {
                    self.role = r
                    await checkProfileAndRoute(userId: userId, role: r)
                } else {
                    self.route = .roleSelect
                }
            } else {
                self.route = .login
            }
        } catch {
            print("Bootstrap error: \(error.localizedDescription)")
            self.route = .login
        }
    }

    func handleSignedIn(userId: String) async {
        do {
            if let r = try await backend.fetchUserRole(userId: userId) {
                self.role = r
                await checkProfileAndRoute(userId: userId, role: r)
            } else {
                self.route = .roleSelect
            }
        } catch {
            print("Handle signed in error: \(error.localizedDescription)")
            self.route = .roleSelect
        }
    }

    func select(role: UserRole) async {
        guard let userId = backend.currentUserId else { return }
        do {
            try await backend.setUserRole(userId: userId, role: role)
            self.role = role
            await checkProfileAndRoute(userId: userId, role: role)
        } catch {
            print("Select role error: \(error.localizedDescription)")
            // handle error
        }
    }
    
    // New helper to fetch profile and decide route
    private func checkProfileAndRoute(userId: String, role: UserRole) async {
        do {
            switch role {
            case .seeker:
                if let profile = try await backend.fetchSeekerProfile(userId: userId) {
                    self.seekerProfile = profile
                    // If seeker is not fully verified (ID, quiz, or contact), send to onboarding
                    if profile.isIDVerified != true || profile.sideGigBasicsQuizCompletedAt == nil || profile.isContactVerified != true {
                        self.route = .seekerOnboarding
                    } else {
                        self.route = .seekerHome
                    }
                } else {
                    // No seeker profile found, send to onboarding to create it
                    self.route = .seekerOnboarding
                }
            case .business:
                if let profile = try await backend.fetchBusinessProfile(userId: userId) {
                    self.businessProfile = profile
                    // If business is not verified, send to onboarding
                    if profile.isVerifiedLocal != true {
                        self.route = .businessOnboarding
                    } else {
                        self.route = .businessHome
                    }
                } else {
                    // No business profile found, send to onboarding to create it
                    self.route = .businessOnboarding
                }
            }
        } catch {
            print("Error checking profile and routing: \(error.localizedDescription)")
            // Default to login or a generic error screen if profile fetching fails
            self.route = .login
        }
    }


    func signOut() async {
        do { try await backend.signOut() } catch {}
        self.role = nil
        self.seekerProfile = nil
        self.businessProfile = nil
        self.route = .login
    }
}

