//
//  SeekerTabView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI
import Combine

struct SeekerTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            // Tab 1: Map for browsing gigs geographically
            SeekerMapView()
                .tabItem { Label("Map", systemImage: "map") }
            
            // Tab 2: The new consolidated "My Gigs" view
            SeekerGigsView()
                .tabItem { Label("My Gigs", systemImage: "list.bullet") }
            
            // Tab 3: The new "For You" discovery feed
            SeekerDiscoveryView()
                .tabItem { Label("For You", systemImage: "sparkles") }
            
            // Tab 4: Messages
            SeekerMessageThreadsView()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }

            // Tab 5: User Profile
            SeekerProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    SeekerTabView().environmentObject(AppState(backend: Back4AppService()))
}
