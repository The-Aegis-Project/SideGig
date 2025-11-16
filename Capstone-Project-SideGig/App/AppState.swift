//
//  AppState.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//


import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Route: Equatable {
        case login
        case roleSelect
        case seekerHome
        case businessHome
    }

    @Published var route: Route = .login
    @Published var role: UserRole? = nil
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
                    self.route = (r == .seeker) ? .seekerHome : .businessHome
                } else {
                    self.route = .roleSelect
                }
            } else {
                self.route = .login
            }
        } catch {
            self.route = .login
        }
    }

    func handleSignedIn(userId: String) async {
        do {
            if let r = try await backend.fetchUserRole(userId: userId) {
                self.role = r
                self.route = (r == .seeker) ? .seekerHome : .businessHome
            } else {
                self.route = .roleSelect
            }
        } catch {
            self.route = .roleSelect
        }
    }

    func select(role: UserRole) async {
        guard let userId = backend.currentUserId else { return }
        do {
            try await backend.setUserRole(userId: userId, role: role)
            self.role = role
            self.route = (role == .seeker) ? .seekerHome : .businessHome
        } catch {
            // handle error
        }
    }

    func signOut() async {
        do { try await backend.signOut() } catch {}
        self.role = nil
        self.route = .login
    }
}
