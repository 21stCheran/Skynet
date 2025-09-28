//
//  GameControllerView.swift
//  Skynet
//

import SwiftUI
#if canImport(GameController)
import GameController
#endif

struct GameControllerView: View {
    @EnvironmentObject var droneManager: DroneManager
    @StateObject private var controllerManager = GameControllerManager()
    
    var body: some View {
        VStack(spacing: 20) {
            // Controller Status
            ControllerStatusView()
                .environmentObject(controllerManager)
            
            if controllerManager.isControllerConnected {
                // Controller Layout Guide
                ControllerLayoutView()
                    .environmentObject(controllerManager)
                
                // Live Input Visualizer
                ControllerInputVisualizerView()
                    .environmentObject(controllerManager)
            } else {
                ControllerSetupView()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            controllerManager.setupControllerHandlers(droneManager: droneManager)
        }
    }
}

// MARK: - Controller Status View
struct ControllerStatusView: View {
    @EnvironmentObject var controllerManager: GameControllerManager
    
    var body: some View {
        GroupBox("Controller Status") {
            HStack {
                Image(systemName: controllerManager.isControllerConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.title2)
                    .foregroundColor(controllerManager.isControllerConnected ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(controllerManager.isControllerConnected ? "Controller Connected" : "No Controller")
                        .font(.headline)
                        .foregroundColor(controllerManager.isControllerConnected ? .green : .gray)
                    
                    if controllerManager.isControllerConnected {
                        Text(controllerManager.controllerName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Connect a DualSense or Xbox controller")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Controller Layout Guide
struct ControllerLayoutView: View {
    var body: some View {
        GroupBox("Control Layout") {
            VStack(alignment: .leading, spacing: 12) {
                ControlMappingRow(control: "R2", action: "Throttle +5%", color: .green)
                ControlMappingRow(control: "L2", action: "Throttle -5%", color: .orange)
                ControlMappingRow(control: "D-Pad", action: "Movement (↑↓←→)", color: .blue)
                ControlMappingRow(control: "R1", action: "Yaw Right (45°)", color: .purple)
                ControlMappingRow(control: "L1", action: "Yaw Left (45°)", color: .purple)
                ControlMappingRow(control: "X", action: "Arm Drone", color: .green)
                ControlMappingRow(control: "A", action: "Safe Disarm", color: .orange)
                ControlMappingRow(control: "Y", action: "Emergency Stop", color: .red)
            }
            .padding()
        }
    }
}

struct ControlMappingRow: View {
    let control: String
    let action: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(control)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(action)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Controller Input Visualizer
struct ControllerInputVisualizerView: View {
    @EnvironmentObject var controllerManager: GameControllerManager
    
    var body: some View {
        GroupBox("Live Input") {
            VStack(spacing: 15) {
                // Trigger Values
                HStack(spacing: 30) {
                    TriggerIndicator(title: "L2", value: controllerManager.leftTrigger, color: .orange)
                    TriggerIndicator(title: "R2", value: controllerManager.rightTrigger, color: .green)
                }
                
                // D-Pad Status
                DPadIndicator(
                    up: controllerManager.dpadUp,
                    down: controllerManager.dpadDown,
                    left: controllerManager.dpadLeft,
                    right: controllerManager.dpadRight
                )
                
                // Button Status
                HStack(spacing: 20) {
                    ButtonIndicator(title: "L1", pressed: controllerManager.leftShoulder, color: .purple)
                    ButtonIndicator(title: "R1", pressed: controllerManager.rightShoulder, color: .purple)
                    ButtonIndicator(title: "□", pressed: controllerManager.squareButton, color: .green)
                    ButtonIndicator(title: "○", pressed: controllerManager.circleButton, color: .orange)
                    ButtonIndicator(title: "△", pressed: controllerManager.triangleButton, color: .red)
                }
            }
            .padding()
        }
    }
}

struct TriggerIndicator: View {
    let title: String
    let value: Float
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(width: 30, height: 60)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 30, height: CGFloat(value) * 60)
                    .animation(.easeInOut(duration: 0.1), value: value)
            }
            
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .monospacedDigit()
        }
    }
}

struct DPadIndicator: View {
    let up: Bool
    let down: Bool
    let left: Bool
    let right: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("D-Pad")
                .font(.caption)
                .fontWeight(.semibold)
            
            VStack(spacing: 2) {
                // Up
                Rectangle()
                    .fill(up ? Color.blue : Color(.systemGray4))
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
                
                HStack(spacing: 2) {
                    // Left
                    Rectangle()
                        .fill(left ? Color.blue : Color(.systemGray4))
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                    
                    // Center
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                    
                    // Right
                    Rectangle()
                        .fill(right ? Color.blue : Color(.systemGray4))
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                }
                
                // Down
                Rectangle()
                    .fill(down ? Color.blue : Color(.systemGray4))
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            }
        }
    }
}

struct ButtonIndicator: View {
    let title: String
    let pressed: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(pressed ? color : Color(.systemGray4))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(pressed ? .white : .secondary)
                )
                .animation(.easeInOut(duration: 0.1), value: pressed)
        }
    }
}

// MARK: - Controller Setup View
struct ControllerSetupView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Controller Connected")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("To use controller mode:")
                    .font(.headline)
                
                Text("1. Connect a DualSense or Xbox controller via Bluetooth")
                Text("2. The controller will be automatically detected")
                Text("3. Use the controls as shown in the layout guide")
            }
            .font(.body)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview {
    GameControllerView()
        .environmentObject(DroneManager())
}