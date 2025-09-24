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
    @State private var isListening = false
    
    private var udpListener = UDPListener()
    private let userDefaults = UserDefaults.standard
    
    var body: some View {
        VStack(spacing: 18) {
            Text("Skynet Telemetry")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Connection Settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Connection Settings")
                    .font(.headline)
                
                TextField("IP Address (e.g., 192.168.4.1)", text: $ip)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                
                TextField("Port (default: 14550)", text: $port)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            // Message Input
            VStack(alignment: .leading, spacing: 10) {
                Text("Send Message")
                    .font(.headline)
                
                TextField("Message to send", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button(action: sendData) {
                        Text("Send UDP Data")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10.0)
                    }
                    
                    Button(action: toggleListener) {
                        Text(isListening ? "Stop Listening" : "Start Listening")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isListening ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10.0)
                    }
                }
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
        port = userDefaults.string(forKey: "lastUsedPort") ?? "14550"
        
        // Set up UDP listener callback
        udpListener.onMessageReceived = { message in
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
    
    func sendData() {
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
        
        // Send UDP message
        UDPSender.sendMessage(message: message, to: ip, port: portNumber) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.alertMessage = "Message sent successfully!"
                    self.message = "" // Clear message after sending
                } else {
                    self.alertMessage = "Failed to send message: \(error ?? "Unknown error")"
                }
                self.showAlert = true
            }
        }
        
        print("-- sending UDP data --")
        print("IP Address: \(ip)")
        print("Port: \(port)")
        print("Message: \(message)")
    }
    
    func toggleListener() {
        if isListening {
            udpListener.stopListening()
            isListening = false
        } else {
            guard let portNumber = UInt16(port) else {
                alertMessage = "Invalid port number for listening"
                showAlert = true
                return
            }
            
            udpListener.startListening(on: portNumber) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isListening = true
                        self.alertMessage = "Started listening on port \(portNumber)"
                    } else {
                        self.alertMessage = "Failed to start listening: \(error ?? "Unknown error")"
                    }
                    self.showAlert = true
                }
            }
        }
    }
}

// MARK: - UDP Sender
class UDPSender {
    static func sendMessage(message: String, to host: String, port: UInt16, completion: @escaping (Bool, String?) -> Void) {
        
        // 1. Use the correct initializer for the port.
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            completion(false, "Invalid port number")
            return
        }
        let hostEndpoint = NWEndpoint.Host(host)
        
        let connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: .udp)
        
        // 2. Use a 'weak' capture list to break the retain cycle.
        // This is the critical fix for the lifecycle bug.
        connection.stateUpdateHandler = { [weak connection] state in
            // Use 'guard let' to safely access the weak reference.
            guard let connection = connection else { return }
            
            switch state {
            case .ready:
                print("Connection is ready, sending UDP packet...")
                let data = message.data(using: .utf8) ?? Data()
                
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Send error: \(error)")
                        completion(false, "Send failed: \(error.localizedDescription)")
                    } else {
                        print("Data sent successfully.")
                        completion(true, "Data sent successfully.")
                    }
                    // Cancel the connection once the send is complete.
                    connection.cancel()
                })
                
            case .failed(let error):
                print("Connection failed: \(error)")
                completion(false, "Connection failed: \(error.localizedDescription)")
                connection.cancel()
                
            default:
                break
            }
        }
        
        // Start the connection on a background queue.
        connection.start(queue: .global())
    }
}

// MARK: - UDP Listener
class UDPListener {
    private var listener: NWListener?
    var onMessageReceived: ((String) -> Void)?
    
    func startListening(on port: UInt16, completion: @escaping (Bool, String?) -> Void) {
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            completion(false, "Invalid port number")
            return
        }
        
        do {
            listener = try NWListener(using: .udp, on: portEndpoint)
        } catch {
            completion(false, error.localizedDescription)
            return
        }
        
        listener?.newConnectionHandler = { connection in
            connection.stateUpdateHandler = { state in
                if state == .ready {
                    self.receiveMessages(on: connection)
                }
            }
            connection.start(queue: .global())
        }
        
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(true, nil)
            case .failed(let error):
                completion(false, error.localizedDescription)
            default:
                break
            }
        }
        
        listener?.start(queue: .global())
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
    }
    
    private func receiveMessages(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8) ?? "Binary data (\(data.count) bytes)"
                self.onMessageReceived?(message)
            }
            
            if !isComplete {
                self.receiveMessages(on: connection)
            }
        }
    }
}
