//
//  MainTabView.swift
//  Skynet
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var droneManager = DroneManager()
    
    var body: some View {
        TabView {
            // Connection Tab
            ConnectionView()
                .tabItem {
                    Image(systemName: "network")
                    Text("Connect")
                }
                .environmentObject(droneManager)
            
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "gauge.high")
                    Text("Dashboard")
                }
                .environmentObject(droneManager)
            
            // Control Tab
            ControlView()
                .tabItem {
                    Image(systemName: "gamecontroller")
                    Text("Control")
                }
                .environmentObject(droneManager)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}