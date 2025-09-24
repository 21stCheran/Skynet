//
//  ContentView.swift
//  Skynet
//
//  Created by Apple on 24/09/25.
//

import SwiftUI
import Network

struct ContentView: View {
    @State private var ip: String = ""
    @State private var port: String = ""
    @State private var message: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var receivedMessages: [String] = []
    @State private var isConnected = false
    @State private var connectionStatus = "Disconnected"
    
    private var udpManager = UDPManager()
    private let userDefaults = UserDefaults.standard
    
    var body: some View {
        VStack(spacing: 18) {
            Text("Skynet Telemetry")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Connection Status
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(connectionStatus)
                    .font(.subheadline)
                    .foregroundColor(isConnected ? .green : .red)
            }
            .padding(.bottom, 10)
            
            // Connection Settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Connection Settings")
                    .font(.headline)
                
                TextField("IP Address (e.g., 192.168.4.1)", text: $ip)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                
                TextField("Port (default: 4210)", text: $port)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            // Connection Control
            HStack {
                Button(action: connectToUDP) {
                    Text(isConnected ? "Disconnect" : "Connect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConnected ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10.0)
                }
            }
            
            // Message Input
            VStack(alignment: .leading, spacing: 10) {
                Text("Send Message")
                    .font(.headline)
                
                TextField("Message to send", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!isConnected)
                
                Button(action: sendMessage) {
                    Text("Send UDP Data")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConnected ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10.0)
                }
                .disabled(!isConnected)
            }
            
            // Message Log
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Received Messages")
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        receivedMessages.removeAll()
                    }
                    .foregroundColor(.red)
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(receivedMessages.enumerated().reversed()), id: \.offset) { index, message in
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(5)
                        }
                    }
                }
                .frame(height: 200)
                .border(Color.gray.opacity(0.3))
            }
        }
        .padding(20)
        .onAppear(perform: loadStoredSettings)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func loadStoredSettings() {
        ip = userDefaults.string(forKey: "lastUsedIP") ?? "192.168.4.1"
        port = userDefaults.string(forKey: "lastUsedPort") ?? "4210"
        
        // Set up UDP manager callbacks
        udpManager.onMessageReceived = { message in
            DispatchQueue.main.async {
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                self.receivedMessages.append("[\(timestamp)] \(message)")
            }
        }
        
        udpManager.onConnectionStatusChanged = { status, isConnected in
            DispatchQueue.main.async {
                self.connectionStatus = status
                self.isConnected = isConnected
            }
        }
    }
    
    func saveSettings() {
        userDefaults.set(ip, forKey: "lastUsedIP")
        userDefaults.set(port, forKey: "lastUsedPort")
    }
    
    func connectToUDP() {
        if isConnected {
            udpManager.disconnect()
            return
        }
        
        guard !ip.isEmpty, !port.isEmpty else {
            alertMessage = "Please enter both IP address and port"
            showAlert = true
            return
        }
        
        guard let portNumber = UInt16(port) else {
            alertMessage = "Invalid port number"
            showAlert = true
            return
        }
        
        // Save settings for next time
        saveSettings()
        
        udpManager.connectToUDP(host: ip, port: portNumber)
        
        print("-- connecting to UDP --")
        print("IP Address: \(ip)")
        print("Port: \(port)")
    }
    
    func sendMessage() {
        guard isConnected else {
            alertMessage = "Not connected to UDP"
            showAlert = true
            return
        }
        
        guard !message.isEmpty else {
            alertMessage = "Please enter a message to send"
            showAlert = true
            return
        }
        
        udpManager.sendMessage(message)
        message = "" // Clear message after sending
        
        print("-- sending UDP message --")
        print("Message: \(message)")
    }
}

// MARK: - UDP Manager
class UDPManager {
    private var connection: NWConnection?
    private var hostUDP: NWEndpoint.Host?
    private var portUDP: NWEndpoint.Port?
    
    var onMessageReceived: ((String) -> Void)?
    var onConnectionStatusChanged: ((String, Bool) -> Void)?
    
    func connectToUDP(host: String, port: UInt16) {
        // Disconnect any existing connection
        disconnect()
        
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            onConnectionStatusChanged?("Invalid port number", false)
            return
        }
        
        hostUDP = NWEndpoint.Host(host)
        portUDP = portEndpoint
        
        connection = NWConnection(host: hostUDP!, port: portUDP!, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            
            print("UDP Connection State: \(newState)")
            
            switch newState {
            case .ready:
                print("State: Ready")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Connected", true)
                }
                self.receiveUDP()
                
            case .setup:
                print("State: Setup")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Setting up...", false)
                }
                
            case .cancelled:
                print("State: Cancelled")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Disconnected", false)
                }
                
            case .preparing:
                print("State: Preparing")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Preparing...", false)
                }
                
            case .failed(let error):
                print("State: Failed - \(error)")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Failed: \(error.localizedDescription)", false)
                }
                
            case .waiting(let error):
                print("State: Waiting - \(error)")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Waiting: \(error.localizedDescription)", false)
                }
                
            @unknown default:
                print("ERROR! State not defined!")
                DispatchQueue.main.async {
                    self.onConnectionStatusChanged?("Unknown state", false)
                }
            }
        }
        
        connection?.start(queue: .global())
    }
    
    func sendMessage(_ content: String) {
        guard let connection = connection else {
            print("No active connection")
            return
        }
        
        let contentToSendUDP = content.data(using: String.Encoding.utf8)
        connection.send(content: contentToSendUDP, completion: NWConnection.SendCompletion.contentProcessed({ error in
            if let error = error {
                print("ERROR! Error when sending data. Error: \(error)")
            } else {
                print("Data was sent to UDP")
            }
        }))
    }
    
    func sendMessage(_ content: Data) {
        guard let connection = connection else {
            print("No active connection")
            return
        }
        
        connection.send(content: content, completion: NWConnection.SendCompletion.contentProcessed({ error in
            if let error = error {
                print("ERROR! Error when sending data. Error: \(error)")
            } else {
                print("Data was sent to UDP")
            }
        }))
    }
    
    func receiveUDP() {
        connection?.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Receive error: \(error)")
                return
            }
            
            if isComplete {
                print("Receive is complete")
                if let data = data, !data.isEmpty {
                    let backToString = String(decoding: data, as: UTF8.self)
                    print("Received message: \(backToString)")
                    DispatchQueue.main.async {
                        self.onMessageReceived?(backToString)
                    }
                } else {
                    print("Data == nil")
                }
                
                // Continue receiving
                self.receiveUDP()
            }
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        onConnectionStatusChanged?("Disconnected", false)
    }
}
