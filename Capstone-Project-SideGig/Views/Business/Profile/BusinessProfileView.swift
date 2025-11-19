//
//  BusinessProfileView.swift
//  Capstone-Project-SideGig
//
//  Created by GitHub Copilot on 11/16/25.
//

import SwiftUI

struct BusinessProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Business") {
                    if let profile = appState.businessProfile {
                        Text(profile.businessName).font(.title2).bold()
                        Text(profile.address).font(.subheadline).foregroundColor(.secondary)
                        HStack { Text("Verified:"); Spacer(); Image(systemName: profile.isVerifiedLocal ? "checkmark.seal.fill" : "xmark.seal").foregroundColor(profile.isVerifiedLocal ? .green : .secondary) }
                        if let rating = profile.avgRating { HStack { Text("Rating:"); Spacer(); Text(String(format: "%.1f", rating)) } }
                    } else {
                        Text("No business profile found.")
                        Button("Reload") { Task { await appState.bootstrap() } }
                    }
                }

                Section("Account") {
                    Text("User ID: \(appState.backend.currentUserId ?? "-")")
                    if let role = appState.role { Text("Role: \(role.displayName)") }
                    Button(role: .destructive) { Task { await appState.signOut() } } label: { Text("Sign Out") }
                }
            }
            .navigationTitle("Business Profile")
        }
    }
}

#Preview {
    BusinessProfileView().environmentObject(AppState(backend: Back4AppService()))
}
