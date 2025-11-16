//
//  RoleSelectView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//


import SwiftUI

struct RoleSelectView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Text("Select your role").font(.largeTitle).bold()
            roleButton(.seeker)
            roleButton(.business)
            Spacer()
        }
        .padding()
    }

    private func roleButton(_ role: UserRole) -> some View {
        Button(action: { Task { await appState.select(role: role) } }) {
            HStack(spacing: 12) {
                Image(systemName: role.systemImageName).font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(role.displayName).font(.headline)
                    Text(role == .seeker ? "I need work" : "I need help").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    RoleSelectView().environmentObject(AppState(backend: Back4AppService()))
}
