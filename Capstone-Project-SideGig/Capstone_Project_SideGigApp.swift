//
//  Capstone_Project_SideGigApp.swift
//  Capstone-Project-SideGig
//
//  Created by Sebastian Torres on 11/15/25.
//

import SwiftUI
import ParseSwift
import GoogleSignIn // Import GoogleSignIn

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
        
        // Configure Google Sign-In
        if let googleClientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
            print("Google Sign-In configured from Info.plist values")
        } else {
            print("Warning: GOOGLE_CLIENT_ID missing from Info.plist — Google Sign-In not fully configured")
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
                // Handle Google Sign-In URL callbacks
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

