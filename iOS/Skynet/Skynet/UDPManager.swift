//
//  UDPManager.swift
//  Skynet
//
//

import Foundation
import Combine
import Network

// MARK: - UDP Manager
class UDPManager: ObservableObject {
    private var connection: NWConnection?
    private var hostUDP: NWEndpoint.Host?
    private var portUDP: NWEndpoint.Port?
    
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    var onMessageReceived: ((String) -> Void)?
    var onDataReceived: ((Data) -> Void)?
    
    func connectToUDP(host: String, port: UInt16) {
        // Disconnect any existing connection
        disconnect()
        
        guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
            updateConnectionStatus("Invalid port number", false)
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
                self.updateConnectionStatus("Connected", true)
                self.receiveUDP()
                
            case .setup:
                print("State: Setup")
                self.updateConnectionStatus("Setting up...", false)
                
            case .cancelled:
                print("State: Cancelled")
                self.updateConnectionStatus("Disconnected", false)
                
            case .preparing:
                print("State: Preparing")
                self.updateConnectionStatus("Preparing...", false)
                
            case .failed(let error):
                print("State: Failed - \(error)")
                self.updateConnectionStatus("Failed: \(error.localizedDescription)", false)
                
            case .waiting(let error):
                print("State: Waiting - \(error)")
                self.updateConnectionStatus("Waiting: \(error.localizedDescription)", false)
                
            @unknown default:
                print("ERROR! State not defined!")
                self.updateConnectionStatus("Unknown state", false)
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
    
    private func receiveUDP() {
        connection?.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Receive error: \(error)")
                // Consider whether to disconnect or just log the error
                // For now, we stop receiving on error.
                return
            }
            
            if isComplete {
                print("Receive is complete")
                if let data = data, !data.isEmpty {
                    // Handle both raw data and string messages
                    DispatchQueue.main.async {
                        self.onDataReceived?(data)
                    }
                    
                    // Also try to decode as string for legacy support
                    let backToString = String(decoding: data, as: UTF8.self)
                    print("Received message: \(backToString)")
                    DispatchQueue.main.async {
                        self.onMessageReceived?(backToString)
                    }
                } else {
                    print("Received empty data")
                }
                
                // Continue receiving for the next message
                self.receiveUDP()
            }
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        updateConnectionStatus("Disconnected", false)
    }
    
    private func updateConnectionStatus(_ status: String, _ connected: Bool) {
        DispatchQueue.main.async {
            self.connectionStatus = status
            self.isConnected = connected
        }
    }
}
