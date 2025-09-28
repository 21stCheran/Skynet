//
//  DroneVisualizerView.swift
//  Skynet
//

import SwiftUI

struct DroneVisualizerView: View {
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.3)]), 
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            
            VStack {
                Text("Drone Orientation")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top)
                
                Spacer()
                
                // 3D Drone Representation
                DroneModel3DView(
                    roll: droneManager.attitudeData.roll,
                    pitch: droneManager.attitudeData.pitch,
                    yaw: droneManager.attitudeData.yaw
                )
                .frame(width: 200, height: 150)
                
                Spacer()
                
                // Attitude Values
                HStack(spacing: 30) {
                    AttitudeValue(title: "Roll", value: droneManager.attitudeData.roll, unit: "°")
                    AttitudeValue(title: "Pitch", value: droneManager.attitudeData.pitch, unit: "°")
                    AttitudeValue(title: "Yaw", value: droneManager.attitudeData.yaw, unit: "°")
                }
                .padding(.bottom)
            }
        }
    }
}

struct DroneModel3DView: View {
    let roll: Float
    let pitch: Float
    let yaw: Float
    
    var body: some View {
        ZStack {
            // Drone body (center)
            Circle()
                .fill(Color.gray)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                )
            
            // Motors/Propellers
            ForEach(0..<4) { i in
                let angle = Double(i) * 90 + Double(yaw)
                
                Circle()
                    .fill(droneManager.isArmed ? Color.red : Color.gray)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .offset(x: cos(angle * .pi / 180) * 60, y: sin(angle * .pi / 180) * 60)
                    .rotationEffect(.degrees(droneManager.isArmed ? Double(Date().timeIntervalSince1970 * 10).truncatingRemainder(dividingBy: 360) : 0))
                    .animation(.linear(duration: 0.1).repeatForever(autoreverses: false), value: droneManager.isArmed)
            }
            
            // Arms
            ForEach(0..<4) { i in
                let angle = Double(i) * 90 + Double(yaw)
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 50)
                    .offset(y: -25)
                    .rotationEffect(.degrees(angle))
            }
            
            // Front indicator (arrow pointing forward)
            Path { path in
                path.move(to: CGPoint(x: 0, y: -15))
                path.addLine(to: CGPoint(x: -5, y: -25))
                path.addLine(to: CGPoint(x: 5, y: -25))
                path.closeSubpath()
            }
            .fill(Color.green)
            .rotationEffect(.degrees(Double(yaw)))
        }
        .rotation3DEffect(
            .degrees(Double(pitch)),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(roll)),
            axis: (x: 0, y: 0, z: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: roll)
        .animation(.easeInOut(duration: 0.2), value: pitch)
        .animation(.easeInOut(duration: 0.2), value: yaw)
    }
    
    @EnvironmentObject var droneManager: DroneManager
}

struct AttitudeValue: View {
    let title: String
    let value: Float
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    DroneVisualizerView()
        .environmentObject(DroneManager())
        .frame(height: 300)
}