//
//  BusinessTabView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI

struct BusinessTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            Text("Dashboard").tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2") }
            Text("Applicants").tabItem { Label("Applicants", systemImage: "person.3") }
            Text("Post Gig").tabItem { Label("Post Gig", systemImage: "plus.circle") }
            Text("Messages").tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    BusinessTabView().environmentObject(AppState(backend: Back4AppService()))
}
