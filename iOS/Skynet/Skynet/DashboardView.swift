//
//  DashboardView.swift
//  Skynet
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Drone Visualizer
                    DroneVisualizerView()
                        .environmentObject(droneManager)
                        .frame(height: 300)
                    
                    // Telemetry Graphs
                    TelemetryGraphsView()
                        .environmentObject(droneManager)
                    
                    // Status Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        StatusCard(title: "Altitude", value: "\(Int(droneManager.altitudeData.altitude))cm", 
                                  icon: "arrow.up.arrow.down", color: .blue)
                        
                        StatusCard(title: "Battery", value: "\(droneManager.statusData.batteryVoltage, specifier: "%.1f")V", 
                                  icon: "battery.100", color: .green)
                        
                        StatusCard(title: "GPS Sats", value: "\(droneManager.gpsData.satellites)", 
                                  icon: "location.circle", color: .orange)
                        
                        StatusCard(title: "Flight Mode", value: droneManager.statusData.flightMode, 
                                  icon: "airplane", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // RC Channel Visualizer
                    RCChannelVisualizerView()
                        .environmentObject(droneManager)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                // Add manual refresh capability if needed
            }
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DroneManager())
}