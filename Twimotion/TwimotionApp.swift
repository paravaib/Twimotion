//
//  TwimotionApp.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import Combine

@main
struct TwimotionApp: App {
    
    // MARK: - App State
    
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(iapManager)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    @EnvironmentObject var iapManager: IAPManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(1)
        }
        .accentColor(.blue)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Handle app foreground events for entitlement checking
            Task {
                await iapManager.handleAppForeground()
            }
        }
    }
}
