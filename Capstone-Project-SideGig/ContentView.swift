//
//  ContentView.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.route {
            case .login:
                LoginView()
            case .roleSelect:
                RoleSelectView()
            case .seekerOnboarding:
                SeekerOnboardingView()
            case .businessOnboarding:
                BusinessOnboardingView()
            case .seekerHome:
                SeekerTabView()
            case .businessHome:
                BusinessTabView()
            }
        }
        .task { await appState.bootstrap() }
    }
}

#Preview {
    ContentView().environmentObject(AppState(backend: Back4AppService()))
}

