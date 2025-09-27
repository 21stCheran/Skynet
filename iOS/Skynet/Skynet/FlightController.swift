//
//  FlightController.swift
//  Skynet
//
//  Flight control interface for drone commands
//

import Foundation
import SwiftUI

// MARK: - Flight Command Models
struct FlightCommand: Codable {
    let command: String
    let value: Int
}

struct FlightResponse: Codable {
    let status: String
    let command: String
    let value: Int
}

// MARK: - Flight Controller Class
class FlightController: ObservableObject {
    @Published var isArmed = false
    @Published var currentCommand = ""
    @Published var commandHistory: [String] = []
    @Published var connectionStatus = "Disconnected"
    
    private var udpManager: UDPManager?
    
    init() {
        setupMessageReceiver()
    }
    
    func setUDPManager(_ manager: UDPManager) {
        self.udpManager = manager
    }
    
    private func setupMessageReceiver() {
        // This will be called when UDP manager receives messages
    }
    
    // MARK: - Basic Flight Commands
    
    func arm() {
        sendCommand(FlightCommand(command: "arm", value: 1))
        isArmed = true
        addToHistory("Armed")
    }
    
    func disarm() {
        sendCommand(FlightCommand(command: "disarm", value: 0))
        isArmed = false
        addToHistory("Disarmed")
    }
    
    func emergencyStop() {
        sendCommand(FlightCommand(command: "stop", value: 0))
        isArmed = false
        addToHistory("EMERGENCY STOP")
    }
    
    // MARK: - Hover Commands
    
    func hoverLow() {
        hover(altitude: 30) // 30cm
    }
    
    func hoverMedium() {
        hover(altitude: 50) // 50cm
    }
    
    func hoverHigh() {
        hover(altitude: 100) // 100cm
    }
    
    func hover(altitude: Int) {
        sendCommand(FlightCommand(command: "hover", value: altitude))
        addToHistory("Hover at \(altitude)cm")
    }
    
    // MARK: - Movement Commands
    
    func moveForward(intensity: Int = 30) {
        sendCommand(FlightCommand(command: "forward", value: intensity))
        addToHistory("Move Forward (\(intensity)%)")
    }
    
    func moveBackward(intensity: Int = 30) {
        sendCommand(FlightCommand(command: "backward", value: intensity))
        addToHistory("Move Backward (\(intensity)%)")
    }
    
    func moveLeft(intensity: Int = 30) {
        sendCommand(FlightCommand(command: "left", value: intensity))
        addToHistory("Move Left (\(intensity)%)")
    }
    
    func moveRight(intensity: Int = 30) {
        sendCommand(FlightCommand(command: "right", value: intensity))
        addToHistory("Move Right (\(intensity)%)")
    }
    
    // MARK: - Helper Methods
    
    private func sendCommand(_ command: FlightCommand) {
        guard let udpManager = udpManager else {
            print("UDP Manager not available")
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(command)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending command: \(jsonString)")
                udpManager.sendMessage(jsonString)
                currentCommand = command.command
            }
        } catch {
            print("Error encoding command: \(error)")
        }
    }
    
    private func addToHistory(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let historyEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.commandHistory.insert(historyEntry, at: 0)
            if self.commandHistory.count > 20 {
                self.commandHistory.removeLast()
            }
        }
    }
    
    // MARK: - Response Handling
    
    func handleResponse(_ responseString: String) {
        do {
            if let responseData = responseString.data(using: .utf8) {
                let response = try JSONDecoder().decode(FlightResponse.self, from: responseData)
                print("Received response: \(response)")
                addToHistory("✓ \(response.command) executed")
            }
        } catch {
            print("Error decoding response: \(error)")
            addToHistory("Response: \(responseString)")
        }
    }
}

// MARK: - Flight Control View
struct FlightControlView: View {
    @StateObject private var flightController = FlightController()
    @ObservedObject var udpManager: UDPManager
    
    init(udpManager: UDPManager) {
        self.udpManager = udpManager
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Flight Control")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Connection Status
            HStack {
                Circle()
                    .fill(udpManager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(udpManager.connectionStatus)
                    .font(.subheadline)
                    .foregroundColor(udpManager.isConnected ? .green : .red)
            }
            
            // Armed Status
            HStack {
                Text("Armed:")
                    .font(.headline)
                Text(flightController.isArmed ? "YES" : "NO")
                    .font(.headline)
                    .foregroundColor(flightController.isArmed ? .red : .green)
            }
            
            // Emergency Stop Button
            Button(action: {
                flightController.emergencyStop()
            }) {
                Text("EMERGENCY STOP")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            
            // Arm/Disarm Buttons
            HStack(spacing: 15) {
                Button(action: {
                    flightController.arm()
                }) {
                    Text("ARM")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(flightController.isArmed ? Color.gray : Color.orange)
                        .cornerRadius(8)
                }
                .disabled(flightController.isArmed)
                
                Button(action: {
                    flightController.disarm()
                }) {
                    Text("DISARM")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(flightController.isArmed ? Color.blue : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!flightController.isArmed)
            }
            
            // Hover Controls
            VStack(spacing: 10) {
                Text("Hover Commands")
                    .font(.headline)
                
                HStack(spacing: 15) {
                    Button("Hover Low\n(30cm)") {
                        flightController.hoverLow()
                    }
                    .buttonStyle(FlightButtonStyle(color: .green))
                    
                    Button("Hover Med\n(50cm)") {
                        flightController.hoverMedium()
                    }
                    .buttonStyle(FlightButtonStyle(color: .blue))
                    
                    Button("Hover High\n(100cm)") {
                        flightController.hoverHigh()
                    }
                    .buttonStyle(FlightButtonStyle(color: .purple))
                }
            }
            
            // Movement Controls
            VStack(spacing: 10) {
                Text("Movement Commands")
                    .font(.headline)
                
                // Forward/Backward
                HStack(spacing: 15) {
                    Button("Forward") {
                        flightController.moveForward()
                    }
                    .buttonStyle(FlightButtonStyle(color: .indigo))
                    
                    Button("Backward") {
                        flightController.moveBackward()
                    }
                    .buttonStyle(FlightButtonStyle(color: .indigo))
                }
                
                // Left/Right
                HStack(spacing: 15) {
                    Button("Left") {
                        flightController.moveLeft()
                    }
                    .buttonStyle(FlightButtonStyle(color: .teal))
                    
                    Button("Right") {
                        flightController.moveRight()
                    }
                    .buttonStyle(FlightButtonStyle(color: .teal))
                }
            }
            
            // Command History
            VStack(alignment: .leading, spacing: 8) {
                Text("Command History")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(flightController.commandHistory, id: \.self) { entry in
                            Text(entry)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            flightController.setUDPManager(udpManager)
            
            // Set up response handling
            udpManager.onMessageReceived = { message in
                flightController.handleResponse(message)
            }
        }
    }
}

// MARK: - Custom Button Style
struct FlightButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? color.opacity(0.7) : color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}