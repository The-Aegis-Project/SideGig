//
//  SeekerProfileView.swift
//  Capstone-Project-SideGig
//
//  Created by GitHub Copilot on 11/16/25.
//

import SwiftUI
import ParseSwift

struct SeekerProfileView: View {
    @EnvironmentObject var appState: AppState

    @State private var email: String? = nil
    @State private var phone: String? = nil
    @State private var memberSinceYear: String? = nil
    @State private var gigsCompleted: Int = 0
    @State private var isLoadingCounts = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack(alignment: .center, spacing: 16) {
                        // Avatar / initials
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)

                            Text(initials)
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.seekerProfile?.fullName ?? "New Seeker")
                                .font(.title2).bold()

                            HStack(spacing: 8) {
                                // Verified badge
                                if appState.seekerProfile?.isIDVerified == true || appState.seekerProfile?.isContactVerified == true {
                                    Label("Verified", systemImage: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Label("Unverified", systemImage: "xmark.seal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let year = memberSinceYear {
                                    Text("Member since \(year)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let e = email {
                                Text(e)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            if let p = phone {
                                Text(p)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Stats chips
                    HStack(spacing: 12) {
                        StatChip(color: Color.blue, title: "Gigs", value: String(gigsCompleted), subtitle: "Completed")
                        StatChip(color: Color.yellow, title: "Badges", value: String(appState.seekerProfile?.skillBadges.count ?? 0), subtitle: "Earned")
                        StatChip(color: Color.red, title: "Reliability", value: appState.seekerProfile?.reliabilityBadgeEarned == true ? "Yes" : "No", subtitle: "Badge")
                    }

                    // Profile details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                            .font(.headline)

                        HStack { Text("User ID:"); Spacer(); Text(appState.backend.currentUserId ?? "-") }
                        HStack { Text("Role:"); Spacer(); Text(appState.role?.displayName ?? "-") }

                        HStack {
                            Text("Contact Verified:")
                            Spacer()
                            Image(systemName: (appState.seekerProfile?.isContactVerified ?? false) ? "phone.fill" : "phone")
                                .foregroundColor((appState.seekerProfile?.isContactVerified ?? false) ? .green : .secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: { Task { await refresh() } }) {
                            HStack {
                                if isLoadingCounts { ProgressView().tint(.white) }
                                Text("Reload profile data")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(role: .destructive) {
                            Task { await appState.signOut() }
                        } label: { Text("Sign Out") }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemRed).opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .onAppear { Task { await refresh() } }
        }
    }

    private var initials: String {
        let name = appState.seekerProfile?.fullName ?? "Seeker"
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
        return initials.isEmpty ? "S" : initials
    }

    private func refresh() async {
        isLoadingCounts = true
        // Fetch email and createdAt from the current user if available
        if let user = SideGigUser.current {
            email = user.email
            if let created = user.createdAt {
                let year = Calendar.current.component(.year, from: created)
                memberSinceYear = String(year)
            }
        }

        // Phone is not stored by default; keep as nil if unavailable
        phone = nil

        // Count completed gigs assigned to this seeker via Parse query
        if let seekerId = appState.backend.currentUserId {
            do {
                let query = GigParse.query().where("assignedSeekerId" == seekerId).where("status" == "complete")
                let results = try await query.find()
                gigsCompleted = results.count
            } catch {
                // ignore errors and keep gigsCompleted as-is
            }
        }

        isLoadingCounts = false
    }
}

struct StatChip: View {
    var color: Color
    var title: String
    var value: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3).bold()
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SeekerProfileView().environmentObject(AppState(backend: Back4AppService()))
}
