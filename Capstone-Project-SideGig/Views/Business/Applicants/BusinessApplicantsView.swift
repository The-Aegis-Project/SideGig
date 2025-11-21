//
//  BusinessApplicantsView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/20/25.
//

import SwiftUI
import Combine

// MARK: - Helper Model
/// A helper struct to combine a Gig with its associated applicants for display purposes.
struct GigWithApplicants: Identifiable {
    let id: String // Uses gig.id as its ID
    let gig: Gig
    var applicants: [SeekerProfile]
}

// MARK: - ViewModel
@MainActor
final class BusinessApplicantsViewModel: ObservableObject {
    @Published var gigsWithApplicants: [GigWithApplicants] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingAssignmentConfirmation: Bool = false
    @Published var selectedSeekerToAssign: SeekerProfile?
    @Published var selectedGigForAssignment: Gig?

    private var backend: BackendService
    private var businessId: String?

    init(backend: BackendService, businessId: String?) {
        self.backend = backend
        self.businessId = businessId
    }

    func updateBackend(_ backend: BackendService) {
        self.backend = backend
    }

    func updateBusinessId(_ id: String?) {
        self.businessId = id
    }

    /// Loads all open gigs for the current business and their respective applicants.
    func loadApplicants() async {
        guard let businessId = businessId else {
            errorMessage = "Business ID not available. Please ensure you are logged in."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let allGigs = try await backend.fetchGigsForBusiness(businessId: businessId)
            var newGigsWithApplicants: [GigWithApplicants] = []

            // Use a TaskGroup to fetch applicants for all eligible gigs concurrently
            try await withThrowingTaskGroup(of: (Gig, [SeekerProfile]).self) { group in
                for gig in allGigs where gig.status == "open" { // Only show applicants for open gigs
                    group.addTask {
                        let applicants = try await self.backend.fetchApplicants(for: gig.id)
                        return (gig, applicants)
                    }
                }
                
                for try await (gig, applicants) in group {
                    if !applicants.isEmpty {
                        newGigsWithApplicants.append(GigWithApplicants(id: gig.id, gig: gig, applicants: applicants))
                    }
                }
            }
            
            // Sort gigs by creation date, newest first, for consistent display
            self.gigsWithApplicants = newGigsWithApplicants.sorted { $0.gig.createdAt > $1.gig.createdAt }
            
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error loading applicants: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    /// Prepares for showing the assignment confirmation alert.
    func confirmAssignment(seeker: SeekerProfile, gig: Gig) {
        selectedSeekerToAssign = seeker
        selectedGigForAssignment = gig
        showingAssignmentConfirmation = true
    }

    /// Executes the assignment of the selected seeker to the selected gig.
    func assignSelectedSeekerToGig() async {
        guard let seeker = selectedSeekerToAssign,
              let gig = selectedGigForAssignment else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await backend.assignSeeker(seekerId: seeker.id, to: gig.id)
            // Reload all applicants to reflect changes:
            // The assigned gig will move from "open" (and thus disappear from this view)
            // and other applicants for that gig will have their applications marked as "rejected".
            await loadApplicants()
            // Clear selections after successful assignment
            selectedSeekerToAssign = nil
            selectedGigForAssignment = nil
            showingAssignmentConfirmation = false
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error assigning seeker: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Views
struct BusinessApplicantsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: BusinessApplicantsViewModel
    
    @State private var selectedSeekerProfile: SeekerProfile? // For presenting seeker profile sheet

    // Modified initializer to allow injecting a ViewModel for previews/testing
    init(viewModel: BusinessApplicantsViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BusinessApplicantsViewModel(backend: Back4AppService(), businessId: nil))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading Applicants...")
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if viewModel.gigsWithApplicants.isEmpty {
                    ContentUnavailableView(
                        "No Open Gigs with Applicants",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("You currently have no open gigs with pending applications. Post a new gig to find help!")
                    )
                } else {
                    ForEach(viewModel.gigsWithApplicants) { gigWithApplicants in
                        Section {
                            ForEach(gigWithApplicants.applicants) { seeker in
                                ApplicantRow(seeker: seeker, gig: gigWithApplicants.gig) {
                                    // Action to view seeker profile
                                    selectedSeekerProfile = seeker
                                } assignAction: {
                                    // Action to assign seeker
                                    viewModel.confirmAssignment(seeker: seeker, gig: gigWithApplicants.gig)
                                }
                            }
                        } header: { // Changed to header: argument for clarity
                            Text(gigWithApplicants.gig.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Applicants")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshApplicants) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.updateBackend(appState.backend)
                viewModel.updateBusinessId(appState.backend.currentUserId)
                refreshApplicants()
            }
            .sheet(item: $selectedSeekerProfile) { seeker in
                // Present the seeker's profile details in a sheet
                SeekerProfileDetailsView(seeker: seeker)
                    .environmentObject(appState) // Pass AppState if needed in details view
            }
            .alert("Assign Seeker to Gig?", isPresented: $viewModel.showingAssignmentConfirmation) {
                Button("Assign", role: .destructive) {
                    Task { await viewModel.assignSelectedSeekerToGig() }
                }
                Button("Cancel", role: .cancel) {
                    // Clear selections if cancelled
                    viewModel.selectedSeekerToAssign = nil
                    viewModel.selectedGigForAssignment = nil
                }
            } message: {
                if let seeker = viewModel.selectedSeekerToAssign, let gig = viewModel.selectedGigForAssignment {
                    Text("Are you sure you want to assign \(seeker.fullName) to \"\(gig.title)\"? This will accept their application and reject others for this gig.")
                } else {
                    Text("Confirm assignment.")
                }
            }
        }
    }

    private func refreshApplicants() {
        Task { await viewModel.loadApplicants() }
    }
}

/// A row view to display an individual applicant's information and actions.
struct ApplicantRow: View {
    let seeker: SeekerProfile
    let gig: Gig // The gig this applicant applied for
    let viewProfileAction: () -> Void
    let assignAction: () -> Void

    var body: some View {
        HStack {
            Button(action: viewProfileAction) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading) {
                        Text(seeker.fullName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(seeker.avgRating.map { String(format: "%.1f", $0) } ?? "N/A")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if seeker.reliabilityBadgeEarned {
                                Image(systemName: "shield.righthalf.filled")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Reliable")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle()) // Make the whole content area for profile tappable
            
            Spacer()

            Button("Assign") {
                assignAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            // Disable assign button if the gig is no longer open (e.g. if another seeker was assigned by another device)
            // This is a defensive check; ideally, gig.status would update and trigger a reload.
            .disabled(gig.status != "open")
        }
        .padding(.vertical, 4)
    }
}

/// A placeholder view to display detailed information about a SeekerProfile.
/// In a real app, this would be a fully developed view.
struct SeekerProfileDetailsView: View {
    let seeker: SeekerProfile
    @Environment(\.dismiss) var dismiss // To dismiss the sheet

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Info") {
                    LabeledContent("Full Name", value: seeker.fullName)
                    LabeledContent("Average Rating", value: seeker.avgRating.map { String(format: "%.1f", $0) } ?? "N/A")
                }
                
                Section("Verification & Badges") {
                    Toggle("ID Verified", isOn: .constant(seeker.isIDVerified))
                        .disabled(true) // Display only
                    Toggle("Contact Verified", isOn: .constant(seeker.isContactVerified))
                        .disabled(true) // Display only
                    LabeledContent("Reliability Badge", value: seeker.reliabilityBadgeEarned ? "Earned" : "Not Earned")
                    if !seeker.skillBadges.isEmpty {
                        Text("Skill Badges: \(seeker.skillBadges.joined(separator: ", "))")
                            .font(.subheadline)
                    } else {
                        Text("No Skill Badges")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let quizScore = seeker.sideGigBasicsQuizScore {
                    Section("SideGig Basics Quiz") {
                        LabeledContent("Score", value: "\(quizScore)%")
                        if let completionDate = seeker.sideGigBasicsQuizCompletedAt {
                            LabeledContent("Completed", value: completionDate.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
            }
            .navigationTitle(seeker.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let mockBackend: BackendService = Back4AppService()
    let appState = AppState(backend: mockBackend)
    
    // Initialize the ViewModel. The .onAppear will update the businessId from appState.backend.currentUserId.
    // In a preview, currentUserId is likely nil, leading to "Business ID not available".
    let viewModel = BusinessApplicantsViewModel(backend: appState.backend, businessId: nil)

    BusinessApplicantsView(viewModel: viewModel)
        .environmentObject(appState)
}
