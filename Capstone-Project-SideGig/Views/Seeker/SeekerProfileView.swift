//
//  SeekerProfileView.swift
//  Capstone-Project-SideGig
//
//  Created by GitHub Copilot on 11/16/25.
//

import SwiftUI

struct SeekerProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    if let profile = appState.seekerProfile {
                        Text(profile.fullName).font(.title2).bold()
                        HStack {
                            Text("ID Verified:")
                            Spacer()
                            Image(systemName: profile.isIDVerified ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundColor(profile.isIDVerified ? .green : .secondary)
                        }
                        HStack {
                            Text("Contact Verified:")
                            Spacer()
                            Image(systemName: (profile.isContactVerified) ? "phone.fill" : "phone")
                                .foregroundColor((profile.isContactVerified) ? .green : .secondary)
                        }
                        if let score = profile.sideGigBasicsQuizScore {
                            HStack { Text("Quiz score:"); Spacer(); Text(String(score)) }
                        }
                    } else {
                        Text("No seeker profile found.")
                        Button("Reload") {
                            Task { await appState.bootstrap() }
                        }
                    }
                }

                Section("Account") {
                    Text("User ID: \(appState.backend.currentUserId ?? "-")")
                    if let role = appState.role { Text("Role: \(role.displayName)") }
                    Button(role: .destructive) {
                        Task { await appState.signOut() }
                    } label: { Text("Sign Out") }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    SeekerProfileView().environmentObject(AppState(backend: Back4AppService()))
}
