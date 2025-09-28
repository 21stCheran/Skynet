//
//  ManualControlView.swift
//  Skynet
//

import SwiftUI

struct ManualControlView: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var movementIntensity: Double = 30
    @State private var throttleValue: Double = 1450
    @State private var manualThrottlePercentage: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Arm/Disarm Section
                ArmingControlSection()
                    .environmentObject(droneManager)
                
                // Movement Controls
                MovementControlSection(intensity: $movementIntensity)
                    .environmentObject(droneManager)
                
                // Throttle Percentage Controls
                ThrottlePercentageControlSection()
                    .environmentObject(droneManager)
                
                // Manual Throttle Percentage Input
                ManualThrottlePercentageSection(manualThrottlePercentage: $manualThrottlePercentage)
                    .environmentObject(droneManager)
                
                // Legacy Throttle Control (for compatibility)
                ThrottleControlSection(throttleValue: $throttleValue)
                    .environmentObject(droneManager)
                
                // Yaw Controls
                YawControlSection(intensity: $movementIntensity)
                    .environmentObject(droneManager)
            }
            .padding()
        }
    }
}

struct ArmingControlSection: View {
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        GroupBox("Flight Status") {
            VStack(spacing: 15) {
                HStack(spacing: 20) {
                    Button(action: { droneManager.armDrone() }) {
                        Label ("Arm", systemImage: "power")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(droneManager.isArmed ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(droneManager.isArmed || !droneManager.isConnected)
                    
                    Button(action: { droneManager.safeDisarm() }) {
                        Label("Safe Disarm", systemImage: "power.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(droneManager.isArmed ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!droneManager.isArmed || !droneManager.isConnected)
                }
                
                Button(action: { droneManager.disarmDrone() }) {
                    Label("Emergency Disarm", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!droneManager.isConnected)
            }
            .padding()
        }
    }
}

struct MovementControlSection: View {
    @EnvironmentObject var droneManager: DroneManager
    @Binding var intensity: Double
    
    var body: some View {
        GroupBox("Movement Controls") {
            VStack(spacing: 15) {
                // Intensity Slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Movement Intensity: \(Int(intensity))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $intensity, in: 10...80, step: 5)
                        .accentColor(.blue)
                }
                
                // Direction pad
                VStack(spacing: 12) {
                    // Forward
                    ControlButton(title: "Forward", icon: "arrow.up", color: .blue) {
                        droneManager.moveForward(intensity: Int(intensity))
                    }
                    
                    HStack(spacing: 40) {
                        // Left
                        ControlButton(title: "Left", icon: "arrow.left", color: .blue) {
                            droneManager.moveLeft(intensity: Int(intensity))
                        }
                        
                        // Right
                        ControlButton(title: "Right", icon: "arrow.right", color: .blue) {
                            droneManager.moveRight(intensity: Int(intensity))
                        }
                    }
                    
                    // Backward
                    ControlButton(title: "Backward", icon: "arrow.down", color: .blue) {
                        droneManager.moveBackward(intensity: Int(intensity))
                    }
                }
            }
            .padding()
        }
    }
}

struct ThrottlePercentageControlSection: View {
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        GroupBox("Throttle Percentage Controls") {
            VStack(spacing: 15) {
                Text("Current Throttle: \(droneManager.currentThrottlePercentage)%")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    ControlButton(title: "+20%", icon: "plus.circle.fill", color: .green) {
                        droneManager.adjustThrottlePercentage(by: 20)
                    }
                    
                    ControlButton(title: "+5%", icon: "plus.circle", color: .green) {
                        droneManager.adjustThrottlePercentage(by: 5)
                    }
                    
                    ControlButton(title: "-5%", icon: "minus.circle", color: .orange) {
                        droneManager.adjustThrottlePercentage(by: -5)
                    }
                    
                    ControlButton(title: "-20%", icon: "minus.circle.fill", color: .orange) {
                        droneManager.adjustThrottlePercentage(by: -20)
                    }
                }
                
                Button(action: { droneManager.setThrottlePercentage(0) }) {
                    Text("Reset to 0%")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(droneManager.currentThrottlePercentage == 0)
            }
            .padding()
        }
    }
}

struct ManualThrottlePercentageSection: View {
    @EnvironmentObject var droneManager: DroneManager
    @Binding var manualThrottlePercentage: Double
    
    var body: some View {
        GroupBox("Manual Throttle Percentage") {
            VStack(spacing: 15) {
                Text("Set Throttle: \(Int(manualThrottlePercentage))%")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Slider(value: $manualThrottlePercentage, in: 0...100, step: 1)
                    .accentColor(.blue)
                
                HStack {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { droneManager.setThrottlePercentage(Int(manualThrottlePercentage)) }) {
                    Text("Apply Throttle Percentage")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!droneManager.isArmed || !droneManager.isConnected)
            }
            .padding()
        }
    }
}

struct ThrottleControlSection: View {
    @EnvironmentObject var droneManager: DroneManager
    @Binding var throttleValue: Double
    
    var body: some View {
        GroupBox("Legacy Direct Throttle Control") {
            VStack(spacing: 15) {
                Text("Throttle: \(Int(throttleValue))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Slider(value: $throttleValue, in: 1000...1800, step: 10)
                    .accentColor(.red)
                
                HStack {
                    Text("1000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("1500")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("1800")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { droneManager.safeHover(throttle: Int(throttleValue)) }) {
                    Text("Apply Legacy Throttle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!droneManager.isArmed || !droneManager.isConnected)
            }
            .padding()
        }
    }
}

struct YawControlSection: View {
    @EnvironmentObject var droneManager: DroneManager
    @Binding var intensity: Double
    
    var body: some View {
        GroupBox("Yaw Controls") {
            HStack(spacing: 30) {
                ControlButton(title: "Yaw Left", icon: "arrow.counterclockwise", color: .purple) {
                    droneManager.yawLeft(intensity: Int(intensity))
                }
                
                ControlButton(title: "Yaw Right", icon: "arrow.clockwise", color: .purple) {
                    droneManager.yawRight(intensity: Int(intensity))
                }
            }
            .padding()
        }
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(minWidth: 70, minHeight: 50)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!droneManager.isConnected)
        .opacity(droneManager.isConnected ? 1.0 : 0.5)
    }
}

#Preview {
    ManualControlView()
        .environmentObject(DroneManager())
}