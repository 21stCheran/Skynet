//
//  ControlView.swift
//  Skynet
//

import SwiftUI

struct ControlView: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var selectedControlMode: ControlMode = .manual
    
    enum ControlMode: String, CaseIterable {
        case manual = "Manual"
        case controller = "Controller"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Control Mode Picker
                Picker("Control Mode", selection: $selectedControlMode) {
                    ForEach(ControlMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Safety Status Banner
                if droneManager.isConnected {
                    SafetyStatusBanner()
                        .environmentObject(droneManager)
                }
                
                // Control Interface
                switch selectedControlMode {
                case .manual:
                    ManualControlView()
                        .environmentObject(droneManager)
                case .controller:
                    GameControllerView()
                        .environmentObject(droneManager)
                }
                
                Spacer()
            }
            .navigationTitle("Control")
            .navigationBarItems(trailing: HStack {
                RestartESP32Button().environmentObject(droneManager)
                EmergencyStopButton().environmentObject(droneManager)
            })
        }
    }
}

struct SafetyStatusBanner: View {
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        HStack {
            Image(systemName: droneManager.isArmed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(droneManager.isArmed ? .red : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(droneManager.isArmed ? "DRONE ARMED - DANGER" : "Drone Safe")
                    .font(.headline)
                    .foregroundColor(droneManager.isArmed ? .red : .green)
                
                Text("Mode: \(droneManager.statusData.flightMode)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Alt: \(Int(droneManager.altitudeData.altitude))cm")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(droneManager.isArmed ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(droneManager.isArmed ? .red.opacity(0.3) : .green.opacity(0.3)),
            alignment: .bottom
        )
    }
}

struct EmergencyStopButton: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var showConfirmation = false
    
    var body: some View {
        Button(action: { showConfirmation = true }) {
            Image(systemName: "stop.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
        .alert(isPresented: $showConfirmation) {
            Alert(
                title: Text("Emergency Stop"),
                message: Text("This will immediately cut power to all motors. Use only in emergency!"),
                primaryButton: .destructive(Text("STOP")) {
                    droneManager.emergencyStop()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct RestartESP32Button: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var showConfirmation = false
    
    var body: some View {
        Button(action: { showConfirmation = true }) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title2)
                .foregroundColor(.orange)
        }
        .alert(isPresented: $showConfirmation) {
            Alert(
                title: Text("Restart ESP32"),
                message: Text("This will restart the flight controller firmware. The drone will disarm and fall if in flight."),
                primaryButton: .destructive(Text("Restart")) {
                    droneManager.sendRestartCommand()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

#Preview {
    ControlView()
        .environmentObject(DroneManager())
}
