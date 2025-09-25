//
//  ContentView.swift
//  Skynet
//
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
    
    @StateObject private var udpManager = UDPManager()
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
                    .fill(udpManager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(udpManager.connectionStatus)
                    .font(.subheadline)
                    .foregroundColor(udpManager.isConnected ? .green : .red)
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
                    Text(udpManager.isConnected ? "Disconnect" : "Connect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(udpManager.isConnected ? Color.red : Color.blue)
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
                    .disabled(!udpManager.isConnected)
                
                Button(action: sendMessage) {
                    Text("Send UDP Data")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(udpManager.isConnected ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10.0)
                }
                .disabled(!udpManager.isConnected)
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
    }
    
    func saveSettings() {
        userDefaults.set(ip, forKey: "lastUsedIP")
        userDefaults.set(port, forKey: "lastUsedPort")
    }
    
    func connectToUDP() {
        if udpManager.isConnected {
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
        guard udpManager.isConnected else {
            alertMessage = "Not connected to UDP"
            showAlert = true
            return
        }
        
        guard !message.isEmpty else {
            alertMessage = "Please enter a message to send"
            showAlert = true
            return
        }
        
        let messageToSend = message
        udpManager.sendMessage(messageToSend)
        message = "" // Clear message after sending
        
        print("-- sending UDP message --")
        print("Message: \(messageToSend)")
    }
}
