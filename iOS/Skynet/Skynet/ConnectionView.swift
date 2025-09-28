//
//  ConnectionView.swift
//  Skynet
//

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var droneManager: DroneManager
    @State private var host: String = "192.168.4.1"
    @State private var port: String = "14550"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Skynet Drone Control")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Connect to your drone")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Connection Form
                VStack(spacing: 20) {
                    GroupBox("Connection Settings") {
                        VStack(spacing: 15) {
                            HStack {
                                Text("IP Address:")
                                    .frame(width: 100, alignment: .leading)
                                TextField("192.168.4.1", text: $host)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            HStack {
                                Text("Port:")
                                    .frame(width: 100, alignment: .leading)
                                TextField("14550", text: $port)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }
                        }
                        .padding()
                    }
                    
                    // Connection Status
                    HStack {
                        Circle()
                            .fill(droneManager.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(droneManager.connectionStatus)
                            .font(.headline)
                            .foregroundColor(droneManager.isConnected ? .green : .red)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Connect Button
                    Button(action: connectToDrone) {
                        HStack {
                            Image(systemName: droneManager.isConnected ? "wifi.slash" : "wifi")
                            Text(droneManager.isConnected ? "Disconnect" : "Connect")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(droneManager.isConnected ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(host.isEmpty || port.isEmpty)
                }
                .padding()
                
                Spacer()
                
                // Quick Info
                if droneManager.isConnected {
                    GroupBox("Quick Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Armed:")
                                Spacer()
                                Text(droneManager.isArmed ? "YES" : "NO")
                                    .foregroundColor(droneManager.isArmed ? .red : .green)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Text("Flight Mode:")
                                Spacer()
                                Text(droneManager.statusData.flightMode)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Battery:")
                                Spacer()
                                Text("\(droneManager.statusData.batteryVoltage, specifier: "%.1f")V")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Connection")
            .onAppear {
                loadSavedSettings()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Connection Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func connectToDrone() {
        if droneManager.isConnected {
            droneManager.disconnect()
        } else {
            guard let portNumber = UInt16(port) else {
                alertMessage = "Invalid port number"
                showAlert = true
                return
            }
            
            droneManager.connect(host: host, port: portNumber)
            saveSettings()
        }
    }
    
    private func loadSavedSettings() {
        host = UserDefaults.standard.string(forKey: "drone_host") ?? "192.168.4.1"
        port = UserDefaults.standard.string(forKey: "drone_port") ?? "14550"
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(host, forKey: "drone_host")
        UserDefaults.standard.set(port, forKey: "drone_port")
    }
}

#Preview {
    ConnectionView()
        .environmentObject(DroneManager())
}