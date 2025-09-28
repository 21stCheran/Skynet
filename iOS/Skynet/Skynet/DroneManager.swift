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
    @Published var currentAltitudeOffset: Int = 0
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
        currentAltitudeOffset = 0
    }
    
    func safeDisarm() {
        sendCommand(.safeDisarm)
        currentAltitudeOffset = 0
    }
    
    func emergencyStop() {
        sendCommand(.stop)
        currentAltitudeOffset = 0
    }
    
    func adjustAltitude(by offset: Int) {
        currentAltitudeOffset += offset
        sendCommand(.hover(value: currentAltitudeOffset))
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
}

// MARK: - Data Structures

struct AttitudeData {
    var roll: Float = 0.0    // degrees
    var pitch: Float = 0.0   // degrees  
    var yaw: Float = 0.0     // degrees
}

struct AltitudeData {
    var altitude: Float = 0.0      // cm
    var velocity: Float = 0.0      // cm/s
}

struct GPSData {
    var fix: Bool = false
    var satellites: Int = 0
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Float = 0.0      // meters
    var speed: Float = 0.0         // m/s
    var course: Float = 0.0        // degrees
}

struct StatusData {
    var cycleTime: Int = 0
    var i2cErrors: Int = 0
    var isArmed: Bool = false
    var flightMode: String = "UNKNOWN"
    var batteryVoltage: Float = 0.0
}

struct RCData {
    var channels: [Int] = Array(repeating: 1500, count: 8)
    
    var roll: Int { channels.count > 0 ? channels[0] : 1500 }
    var pitch: Int { channels.count > 1 ? channels[1] : 1500 }
    var throttle: Int { channels.count > 2 ? channels[2] : 1000 }
    var yaw: Int { channels.count > 3 ? channels[3] : 1500 }
    var aux1: Int { channels.count > 4 ? channels[4] : 1000 }
}

struct RawIMUData {
    var accelX: Float = 0.0
    var accelY: Float = 0.0
    var accelZ: Float = 0.0
    var gyroX: Float = 0.0
    var gyroY: Float = 0.0
    var gyroZ: Float = 0.0
    var magX: Float = 0.0
    var magY: Float = 0.0
    var magZ: Float = 0.0
}

// MARK: - Command Enum

enum DroneCommand {
    case arm
    case disarm
    case safeDisarm
    case stop
    case hover(value: Int)
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
        case .hover(let value):
            return "{\"command\":\"hover\",\"value\":\(value),\"safeMode\":true}"
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