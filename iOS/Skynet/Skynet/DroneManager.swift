//
//  DroneManager.swift
//  Skynet
//

import Foundation
import Combine
import Network

class DroneManager: ObservableObject {
    // Connection
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    // Telemetry Data
    @Published var attitudeData = AttitudeData()
    @Published var altitudeData = AltitudeData()
    @Published var gpsData = GPSData()
    @Published var statusData = StatusData()
    @Published var rcData = RCData()
    @Published var rawIMUData = RawIMUData()
    
    // Command State
    @Published var currentThrottlePercentage: Int = 0
    @Published var isArmed = false
    
    private var udpManager = UDPManager()
    private var mspParser = MSPParser()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind UDP manager state
        udpManager.$isConnected
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        udpManager.$connectionStatus
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // Setup message handler
        udpManager.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
    }
    
    func connect(host: String, port: UInt16) {
        udpManager.connectToUDP(host: host, port: port)
    }
    
    func disconnect() {
        udpManager.disconnect()
    }
    
    private func handleReceivedData(_ data: Data) {
        if let parsedData = mspParser.parseUDPData(data) {
            DispatchQueue.main.async {
                self.updateTelemetryData(parsedData)
                print("Parsed MSP Data: \(parsedData)") // Log parsed data
            }
        }
    }
    
    private func updateTelemetryData(_ data: [String: Any]) {
        if let attitude = data["attitude"] as? AttitudeData {
            self.attitudeData = attitude
        }
        if let altitude = data["altitude"] as? AltitudeData {
            self.altitudeData = altitude
        }
        if let gps = data["gps"] as? GPSData {
            self.gpsData = gps
        }
        if let status = data["status"] as? StatusData {
            self.statusData = status
            self.isArmed = status.isArmed
        }
        if let rc = data["rc"] as? RCData {
            self.rcData = rc
        }
        if let imu = data["rawIMU"] as? RawIMUData {
            self.rawIMUData = imu
        }
    }
    
    // MARK: - Command Functions
    
    func sendCommand(_ command: DroneCommand) {
        let jsonData = command.toJSON()
        udpManager.sendMessage(jsonData)
        print("Sent command: \(jsonData)")
    }
    
    func armDrone() {
        sendCommand(.arm)
    }
    
    func disarmDrone() {
        sendCommand(.disarm)
        currentThrottlePercentage = 0
    }
    
    func safeDisarm() {
        sendCommand(.safeDisarm)
        currentThrottlePercentage = 0
    }
    
    func emergencyStop() {
        sendCommand(.stop)
        currentThrottlePercentage = 0
    }
    
    func adjustThrottlePercentage(by offset: Int) {
        currentThrottlePercentage = max(0, min(100, currentThrottlePercentage + offset))
        sendCommand(.throttlePercentage(value: currentThrottlePercentage))
    }
    
    func setThrottlePercentage(_ percentage: Int) {
        currentThrottlePercentage = max(0, min(100, percentage))
        sendCommand(.throttlePercentage(value: currentThrottlePercentage))
    }
    
    func moveForward(intensity: Int) {
        sendCommand(.forward(value: intensity))
    }
    
    func moveBackward(intensity: Int) {
        sendCommand(.backward(value: intensity))
    }
    
    func moveLeft(intensity: Int) {
        sendCommand(.left(value: intensity))
    }
    
    func moveRight(intensity: Int) {
        sendCommand(.right(value: intensity))
    }
    
    func yawLeft(intensity: Int) {
        sendCommand(.yawLeft(value: intensity))
    }
    
    func yawRight(intensity: Int) {
        sendCommand(.yawRight(value: intensity))
    }
    
    func safeHover(throttle: Int) {
        sendCommand(.safeHover(value: throttle))
    }
    
    func sendDisarmCommand() {
        sendCommand(command: "disarm")
    }

    func sendRestartCommand() {
        sendCommand(command: "restart")
    }

    func sendEmergencyStopCommand() {
        sendCommand(command: "estop")
    }
}

// MARK: - Data Structures are now defined in MSPParser.swift

// MARK: - Command Enum

enum DroneCommand {
    case arm
    case disarm
    case safeDisarm
    case stop
    case throttlePercentage(value: Int)
    case safeHover(value: Int)
    case forward(value: Int)
    case backward(value: Int)
    case left(value: Int)
    case right(value: Int)
    case yawLeft(value: Int)
    case yawRight(value: Int)
    case restart
    
    func toJSON() -> String {
        switch self {
        case .arm:
            return "{\"command\":\"arm\",\"value\":0,\"safeMode\":true}"
        case .disarm:
            return "{\"command\":\"disarm\",\"value\":0,\"safeMode\":true}"
        case .safeDisarm:
            return "{\"command\":\"safe_disarm\",\"value\":0,\"safeMode\":true}"
        case .stop:
            return "{\"command\":\"stop\",\"value\":0,\"safeMode\":true}"
        case .throttlePercentage(let value):
            return "{\"command\":\"throttle_percentage\",\"value\":\(value),\"safeMode\":true}"
        case .safeHover(let value):
            return "{\"command\":\"safe_hover\",\"value\":\(value),\"safeMode\":true}"
        case .forward(let value):
            return "{\"command\":\"forward\",\"value\":\(value),\"safeMode\":true}"
        case .backward(let value):
            return "{\"command\":\"backward\",\"value\":\(value),\"safeMode\":true}"
        case .left(let value):
            return "{\"command\":\"left\",\"value\":\(value),\"safeMode\":true}"
        case .right(let value):
            return "{\"command\":\"right\",\"value\":\(value),\"safeMode\":true}"
        case .yawLeft(let value):
            return "{\"command\":\"yaw_left\",\"value\":\(value),\"safeMode\":true}"
        case .yawRight(let value):
            return "{\"command\":\"yaw_right\",\"value\":\(value),\"safeMode\":true}"
        case .restart:
            return "{\"command\":\"restart\",\"value\":0,\"safeMode\":true}"
        }
    }
}
