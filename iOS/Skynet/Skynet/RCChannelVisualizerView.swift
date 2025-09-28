//
//  RCChannelVisualizerView.swift
//  Skynet
//

import SwiftUI

struct RCChannelVisualizerView: View {
    @EnvironmentObject var droneManager: DroneManager
    
    var body: some View {
        VStack(spacing: 15) {
            Text("RC Channels")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                RCChannelBar(title: "Roll", value: droneManager.rcData.roll, color: .red)
                RCChannelBar(title: "Pitch", value: droneManager.rcData.pitch, color: .green)
                RCChannelBar(title: "Throttle", value: droneManager.rcData.throttle, color: .blue)
                RCChannelBar(title: "Yaw", value: droneManager.rcData.yaw, color: .orange)
                RCChannelBar(title: "AUX1", value: droneManager.rcData.aux1, color: .purple)
                RCChannelBar(title: "AUX2", value: droneManager.rcData.channels.count > 5 ? droneManager.rcData.channels[5] : 1500, color: .pink)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct RCChannelBar: View {
    let title: String
    let value: Int
    let color: Color
    
    private var normalizedValue: Double {
        // Normalize RC value (1000-2000) to 0-1 range
        return Double(max(1000, min(2000, value)) - 1000) / 1000.0
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 8)
                    
                    // Value bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * normalizedValue, height: 8)
                        .animation(.easeInOut(duration: 0.1), value: normalizedValue)
                    
                    // Center line indicator (1500)
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 1, height: 12)
                        .offset(x: geometry.size.width * 0.5)
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    RCChannelVisualizerView()
        .environmentObject(DroneManager())
        .padding()
}