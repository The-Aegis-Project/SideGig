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
            Text("Map Placeholder").tabItem { Label("Map", systemImage: "map") }
            Text("My Gigs").tabItem { Label("My Gigs", systemImage: "list.bullet") }
            Text("Saved").tabItem { Label("Saved", systemImage: "bookmark") }
            Text("Messages").tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    SeekerTabView().environmentObject(AppState(backend: Back4AppService()))
}
