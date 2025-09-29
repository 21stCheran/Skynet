import Foundation

// MARK: - Data Structures for MSP Parsing

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
        _ = UInt16(payload[4]) | (UInt16(payload[5]) << 8)
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

// MARK: - Usage Example in your iPhone App
class DroneDataManager {
    private let mspParser = MSPParser()
        
    func handleReceivedData(_ data: Data) {
        if let parsedData = mspParser.parseUDPData(data) {
            // Handle parsed data
            if let attitude = parsedData["attitude"] as? AttitudeData {
                updateAttitudeDisplay(attitude: attitude)
            }
            
            if let status = parsedData["status"] as? StatusData {
                updateArmedStatus(status.isArmed)
            }
            
            if let gps = parsedData["gps"] as? GPSData {
                updateGPSPosition(gps: gps)
            }
        }
    }
    
    private func updateAttitudeDisplay(attitude: AttitudeData) {
        DispatchQueue.main.async {
            // Update your UI with attitude data
            print("Attitude - Roll: \(attitude.roll)°, Pitch: \(attitude.pitch)°, Yaw: \(attitude.yaw)°")
        }
    }
    
    private func updateArmedStatus(_ armed: Bool) {
        DispatchQueue.main.async {
            // Update armed/disarmed indicator
            print("Drone \(armed ? "ARMED" : "DISARMED")")
        }
    }
    
    private func updateGPSPosition(gps: GPSData) {
        DispatchQueue.main.async {
            // Update GPS position on map
            print("GPS Position: \(gps.latitude), \(gps.longitude)")
        }
    }
}
