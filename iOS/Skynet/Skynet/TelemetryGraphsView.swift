//
//  TelemetryGraphsView.swift
//  Skynet
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct TelemetryGraphsView: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var altitudeHistory: [DataPoint] = []
    @State private var rollHistory: [DataPoint] = []
    @State private var pitchHistory: [DataPoint] = []
    @State private var yawHistory: [DataPoint] = []
    
    private let maxDataPoints = 50
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Telemetry Graphs")
                .font(.headline)
                .padding(.top)
            
            // Altitude Graph
            GraphCard(title: "Altitude (cm)", color: .blue) {
                #if canImport(Charts)
                if #available(iOS 16.0, *) {
                    Chart(altitudeHistory) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Altitude", point.value)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartYAxisLabel("cm")
                    .frame(height: 100)
                } else {
                    SimpleGraphView(data: altitudeHistory, color: .blue)
                        .frame(height: 100)
                }
                #else
                SimpleGraphView(data: altitudeHistory, color: .blue)
                    .frame(height: 100)
                #endif
            }
            
            // Attitude Graphs
            HStack(spacing: 15) {
                GraphCard(title: "Roll (°)", color: .red) {
                    #if canImport(Charts)
                    if #available(iOS 16.0, *) {
                        Chart(rollHistory) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Roll", point.value)
                            )
                            .foregroundStyle(.red)
                        }
                        .chartYAxisLabel("°")
                        .frame(height: 80)
                    } else {
                        SimpleGraphView(data: rollHistory, color: .red)
                            .frame(height: 80)
                    }
                    #else
                    SimpleGraphView(data: rollHistory, color: .red)
                        .frame(height: 80)
                    #endif
                }
                
                GraphCard(title: "Pitch (°)", color: .green) {
                    #if canImport(Charts)
                    if #available(iOS 16.0, *) {
                        Chart(pitchHistory) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Pitch", point.value)
                            )
                            .foregroundStyle(.green)
                        }
                        .chartYAxisLabel("°")
                        .frame(height: 80)
                    } else {
                        SimpleGraphView(data: pitchHistory, color: .green)
                            .frame(height: 80)
                    }
                    #else
                    SimpleGraphView(data: pitchHistory, color: .green)
                        .frame(height: 80)
                    #endif
                }
            }
            
            GraphCard(title: "Yaw (°)", color: .orange) {
                #if canImport(Charts)
                if #available(iOS 16.0, *) {
                    Chart(yawHistory) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Yaw", point.value)
                        )
                        .foregroundStyle(.orange)
                    }
                    .chartYAxisLabel("°")
                    .frame(height: 100)
                } else {
                    SimpleGraphView(data: yawHistory, color: .orange)
                        .frame(height: 100)
                }
                #else
                SimpleGraphView(data: yawHistory, color: .orange)
                    .frame(height: 100)
                #endif
            }
        }
        .padding()
        .onReceive(timer) { _ in
            updateGraphData()
        }
    }
    
    private func updateGraphData() {
        let now = Date()
        
        // Add new data points
        altitudeHistory.append(DataPoint(timestamp: now, value: Double(droneManager.altitudeData.altitude)))
        rollHistory.append(DataPoint(timestamp: now, value: Double(droneManager.attitudeData.roll)))
        pitchHistory.append(DataPoint(timestamp: now, value: Double(droneManager.attitudeData.pitch)))
        yawHistory.append(DataPoint(timestamp: now, value: Double(droneManager.attitudeData.yaw)))
        
        // Keep only the latest data points
        if altitudeHistory.count > maxDataPoints {
            altitudeHistory.removeFirst()
        }
        if rollHistory.count > maxDataPoints {
            rollHistory.removeFirst()
        }
        if pitchHistory.count > maxDataPoints {
            pitchHistory.removeFirst()
        }
        if yawHistory.count > maxDataPoints {
            yawHistory.removeFirst()
        }
    }
}

struct GraphCard<Content: View>: View {
    let title: String
    let color: Color
    let content: Content
    
    init(title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(color)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

// MARK: - Simple Graph Fallback
struct SimpleGraphView: View {
    let data: [DataPoint]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            if !data.isEmpty {
                let maxValue = data.map(\.value).max() ?? 1
                let minValue = data.map(\.value).min() ?? 0
                let valueRange = maxValue - minValue
                
                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) / CGFloat(max(data.count - 1, 1)) * geometry.size.width
                        let normalizedValue = valueRange > 0 ? (point.value - minValue) / valueRange : 0.5
                        let y = geometry.size.height - (normalizedValue * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 2)
            } else {
                Text("No Data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    TelemetryGraphsView()
        .environmentObject(DroneManager())
}