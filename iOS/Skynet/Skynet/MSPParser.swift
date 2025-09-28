import Foundation

// MARK: - MSP Packet Parser for iPhone
class MSPParser {
    
    // MSP Commands
    enum MSPCommand: UInt8 {
        case STATUS = 101      // 0x65 - Flight status, battery, armed state
        case ATTITUDE = 108    // 0x6C - Roll, pitch, yaw
        case RAW_GPS = 106     // 0x6A - GPS coordinates
        case RAW_IMU = 102     // 0x66 - Accelerometer, gyro, magnetometer
        case ALTITUDE = 109    // 0x6D - Altitude and climb rate
        case RC = 105          // 0x69 - RC channel values
        case MOTOR = 104       // 0x68 - Motor outputs
    }
    
    // Parse incoming raw UDP data
    func parseUDPData(_ data: Data) -> [String: Any]? {
        guard data.count >= 6 else { return nil }
        
        let bytes = [UInt8](data)
        
        // Check MSP header: $M>
        guard bytes[0] == 0x24, bytes[1] == 0x4D, bytes[2] == 0x3E else {
            return nil
        }
        
        let payloadSize = bytes[3]
        let command = bytes[4]
        
        guard data.count >= Int(payloadSize) + 6 else { return nil }
        
        let payload = Array(bytes[5..<(5 + Int(payloadSize))])
        
        var result: [String: Any] = [:]
        
        switch command {
        case MSPCommand.ATTITUDE.rawValue:
            if let attitude = parseAttitude(payload) {
                result["attitude"] = attitude
            }
            
        case MSPCommand.ALTITUDE.rawValue:
            if let altitude = parseAltitude(payload) {
                result["altitude"] = altitude
            }
            
        case MSPCommand.RAW_GPS.rawValue:
            if let gps = parseGPS(payload) {
                result["gps"] = gps
            }
            
        case MSPCommand.STATUS.rawValue:
            if let status = parseStatus(payload) {
                result["status"] = status
            }
            
        case MSPCommand.RC.rawValue:
            if let rc = parseRC(payload) {
                result["rc"] = rc
            }
            
        case MSPCommand.RAW_IMU.rawValue:
            if let imu = parseRawIMU(payload) {
                result["rawIMU"] = imu
            }
            
        default:
            break
        }
        
        return result.isEmpty ? nil : result
    }
    
    private func parseAttitude(_ payload: [UInt8]) -> AttitudeData? {
        guard payload.count >= 6 else { return nil }
        
        // MSP_ATTITUDE format: int16_t roll, int16_t pitch, int16_t yaw (degrees * 10)
        let roll = Float(Int16(payload[0]) | (Int16(payload[1]) << 8)) / 10.0
        let pitch = Float(Int16(payload[2]) | (Int16(payload[3]) << 8)) / 10.0
        let yaw = Float(Int16(payload[4]) | (Int16(payload[5]) << 8)) / 10.0
        
        return AttitudeData(roll: roll, pitch: pitch, yaw: yaw)
    }
    
    private func parseAltitude(_ payload: [UInt8]) -> AltitudeData? {
        guard payload.count >= 6 else { return nil }
        
        // MSP_ALTITUDE format: int32_t altitude (cm), int16_t velocity (cm/s)
        let altitude = Float(Int32(payload[0]) | (Int32(payload[1]) << 8) | (Int32(payload[2]) << 16) | (Int32(payload[3]) << 24))
        let velocity = Float(Int16(payload[4]) | (Int16(payload[5]) << 8))
        
        return AltitudeData(altitude: altitude, velocity: velocity)
    }
    
    private func parseGPS(_ payload: [UInt8]) -> GPSData? {
        guard payload.count >= 16 else { return nil }
        
        let fix = payload[0] != 0
        let satellites = Int(payload[1])
        
        let lat = Int32(payload[2]) | (Int32(payload[3]) << 8) | (Int32(payload[4]) << 16) | (Int32(payload[5]) << 24)
        let lon = Int32(payload[6]) | (Int32(payload[7]) << 8) | (Int32(payload[8]) << 16) | (Int32(payload[9]) << 24)
        
        let latitude = Double(lat) / 10000000.0
        let longitude = Double(lon) / 10000000.0
        
        let altitude = Float(UInt16(payload[10]) | (UInt16(payload[11]) << 8))
        let speed = Float(UInt16(payload[12]) | (UInt16(payload[13]) << 8))
        let course = Float(UInt16(payload[14]) | (UInt16(payload[15]) << 8)) / 10.0
        
        return GPSData(fix: fix, satellites: satellites, latitude: latitude, longitude: longitude, 
                      altitude: altitude, speed: speed, course: course)
    }
    
    private func parseStatus(_ payload: [UInt8]) -> StatusData? {
        guard payload.count >= 11 else { return nil }
        
        let cycleTime = Int(UInt16(payload[0]) | (UInt16(payload[1]) << 8))
        let i2cErrors = Int(UInt16(payload[2]) | (UInt16(payload[3]) << 8))
        let sensors = UInt16(payload[4]) | (UInt16(payload[5]) << 8)
        let flightModes = UInt32(payload[6]) | (UInt32(payload[7]) << 8) | (UInt32(payload[8]) << 16) | (UInt32(payload[9]) << 24)
        
        let isArmed = (flightModes & 0x01) != 0
        let flightMode = decodeFlightMode(flightModes)
        let batteryVoltage = payload.count > 10 ? Float(payload[10]) / 10.0 : 0.0
        
        return StatusData(cycleTime: cycleTime, i2cErrors: i2cErrors, isArmed: isArmed, 
                         flightMode: flightMode, batteryVoltage: batteryVoltage)
    }
    
    private func parseRC(_ payload: [UInt8]) -> RCData? {
        guard payload.count >= 16 else { return nil } // 8 channels * 2 bytes
        
        var channels: [Int] = []
        for i in 0..<8 {
            let channelValue = Int(UInt16(payload[i*2]) | (UInt16(payload[i*2 + 1]) << 8))
            channels.append(channelValue)
        }
        
        return RCData(channels: channels)
    }
    
    private func parseRawIMU(_ payload: [UInt8]) -> RawIMUData? {
        guard payload.count >= 18 else { return nil }
        
        let accelX = Float(Int16(payload[0]) | (Int16(payload[1]) << 8))
        let accelY = Float(Int16(payload[2]) | (Int16(payload[3]) << 8))
        let accelZ = Float(Int16(payload[4]) | (Int16(payload[5]) << 8))
        
        let gyroX = Float(Int16(payload[6]) | (Int16(payload[7]) << 8))
        let gyroY = Float(Int16(payload[8]) | (Int16(payload[9]) << 8))
        let gyroZ = Float(Int16(payload[10]) | (Int16(payload[11]) << 8))
        
        let magX = Float(Int16(payload[12]) | (Int16(payload[13]) << 8))
        let magY = Float(Int16(payload[14]) | (Int16(payload[15]) << 8))
        let magZ = Float(Int16(payload[16]) | (Int16(payload[17]) << 8))
        
        return RawIMUData(accelX: accelX, accelY: accelY, accelZ: accelZ,
                         gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ,
                         magX: magX, magY: magY, magZ: magZ)
    }
    
    private func decodeFlightMode(_ flightModes: UInt32) -> String {
        if (flightModes & 0x02) != 0 { return "ANGLE" }
        if (flightModes & 0x04) != 0 { return "HORIZON" }
        if (flightModes & 0x08) != 0 { return "NAV_ALTHOLD" }
        if (flightModes & 0x10) != 0 { return "NAV_POSHOLD" }
        if (flightModes & 0x20) != 0 { return "NAV_RTH" }
        if (flightModes & 0x40) != 0 { return "NAV_WP" }
        if (flightModes & 0x80) != 0 { return "HEADFREE" }
        return "ACRO"
    }
}
        }
        
        let payloadLength = bytes[3]
        let command = bytes[4]
        
        guard data.count >= Int(6 + payloadLength) else { return nil }
        
        let payload = Array(bytes[5..<Int(5 + payloadLength)])
        
        // Parse based on command type
        switch MSPCommand(rawValue: command) {
        case .ATTITUDE:
            return parseAttitude(payload)
            
        case .STATUS:
            return parseStatus(payload)
            
        case .RAW_GPS:
            return parseGPS(payload)
            
        default:
            return ["type": "unknown", "command": command, "payload": payload]
        }
    }
    
    // Parse attitude data (roll, pitch, yaw)
    private func parseAttitude(_ payload: [UInt8]) -> [String: Any]? {
        guard payload.count >= 6 else { return nil }
        
        let roll = Int16(payload[0]) | (Int16(payload[1]) << 8)
        let pitch = Int16(payload[2]) | (Int16(payload[3]) << 8)
        let yaw = Int16(payload[4]) | (Int16(payload[5]) << 8)
        
        // Convert from decidegrees to degrees
        let rollDeg = Float(roll) / 10.0
        let pitchDeg = Float(pitch) / 10.0
        let yawDeg = Float(yaw) / 10.0
        
        return [
            "type": "attitude",
            "roll": rollDeg,
            "pitch": pitchDeg,
            "yaw": yawDeg,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    // Parse status data
    private func parseStatus(_ payload: [UInt8]) -> [String: Any]? {
        guard payload.count >= 11 else { return nil }
        
        let cycleTime = UInt16(payload[0]) | (UInt16(payload[1]) << 8)
        let i2cErrors = UInt16(payload[2]) | (UInt16(payload[3]) << 8)
        let sensors = UInt16(payload[4]) | (UInt16(payload[5]) << 8)
        let flightModes = UInt32(payload[6]) | (UInt32(payload[7]) << 8) | 
                         (UInt32(payload[8]) << 16) | (UInt32(payload[9]) << 24)
        let profile = payload[10]
        
        return [
            "type": "status",
            "cycleTime": cycleTime,
            "i2cErrors": i2cErrors,
            "sensors": sensors,
            "flightModes": flightModes,
            "profile": profile,
            "armed": (flightModes & 0x01) != 0,  // Check armed bit
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    // Parse GPS data
    private func parseGPS(_ payload: [UInt8]) -> [String: Any]? {
        guard payload.count >= 16 else { return nil }
        
        let fix = payload[0]
        let satellites = payload[1]
        let lat = Int32(payload[2]) | (Int32(payload[3]) << 8) | 
                 (Int32(payload[4]) << 16) | (Int32(payload[5]) << 24)
        let lon = Int32(payload[6]) | (Int32(payload[7]) << 8) | 
                 (Int32(payload[8]) << 16) | (Int32(payload[9]) << 24)
        let altitude = UInt16(payload[10]) | (UInt16(payload[11]) << 8)
        let speed = UInt16(payload[12]) | (UInt16(payload[13]) << 8)
        let course = UInt16(payload[14]) | (UInt16(payload[15]) << 8)
        
        // Convert coordinates to degrees
        let latitude = Double(lat) / 10000000.0
        let longitude = Double(lon) / 10000000.0
        
        return [
            "type": "gps",
            "fix": fix,
            "satellites": satellites,
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "speed": speed,
            "course": course,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Usage Example in your iPhone App
class DroneDataManager {
    private let mspParser = MSPParser()
    
    func handleReceivedData(_ data: Data) {
        if let parsedData = mspParser.parseUDPData(data) {
            // Handle parsed data
            guard let type = parsedData["type"] as? String else { return }
            
            switch type {
            case "attitude":
                if let roll = parsedData["roll"] as? Float,
                   let pitch = parsedData["pitch"] as? Float,
                   let yaw = parsedData["yaw"] as? Float {
                    updateAttitudeDisplay(roll: roll, pitch: pitch, yaw: yaw)
                }
                
            case "status":
                if let armed = parsedData["armed"] as? Bool {
                    updateArmedStatus(armed)
                }
                
            case "gps":
                if let lat = parsedData["latitude"] as? Double,
                   let lon = parsedData["longitude"] as? Double {
                    updateGPSPosition(latitude: lat, longitude: lon)
                }
                
            default:
                print("Unknown data type: \(type)")
            }
        }
    }
    
    private func updateAttitudeDisplay(roll: Float, pitch: Float, yaw: Float) {
        DispatchQueue.main.async {
            // Update your UI with attitude data
            print("Attitude - Roll: \(roll)°, Pitch: \(pitch)°, Yaw: \(yaw)°")
        }
    }
    
    private func updateArmedStatus(_ armed: Bool) {
        DispatchQueue.main.async {
            // Update armed/disarmed indicator
            print("Drone \(armed ? "ARMED" : "DISARMED")")
        }
    }
    
    private func updateGPSPosition(latitude: Double, longitude: Double) {
        DispatchQueue.main.async {
            // Update GPS position on map
            print("GPS Position: \(latitude), \(longitude)")
        }
    }
}