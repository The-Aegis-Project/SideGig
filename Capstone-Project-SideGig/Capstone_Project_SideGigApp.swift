//
//  Capstone_Project_SideGigApp.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI
import ParseSwift

@main
struct Capstone_Project_SideGigApp: App {
    @StateObject private var appState: AppState

    init() {
        // Initialize ParseSwift using keys substituted into Info.plist via Keys.xcconfig.
        // If keys are missing, we log a warning and do not initialize Parse here.
        let serverURL = URL(string: "https://parseapi.back4app.com")!
        if let appId = Bundle.main.object(forInfoDictionaryKey: "BACK4APP_APPLICATION_ID") as? String,
           let clientKey = Bundle.main.object(forInfoDictionaryKey: "BACK4APP_CLIENT_KEY") as? String {
            ParseSwift.initialize(applicationId: appId, clientKey: clientKey, serverURL: serverURL)
            print("Parse initialized from Info.plist values")
        } else {
            print("Warning: Back4App keys missing from Info.plist — Parse not initialized")
        }

        _appState = StateObject(wrappedValue: AppState(backend: Back4AppService()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
