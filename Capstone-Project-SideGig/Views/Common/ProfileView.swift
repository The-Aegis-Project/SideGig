//
//  ProfileView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//


import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
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
    ProfileView().environmentObject(AppState(backend: Back4AppService()))
}
