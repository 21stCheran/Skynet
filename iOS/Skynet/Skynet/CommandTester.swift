//
//  CommandTester.swift
//  Skynet
//
//  For testing flight commands without actual hardware
//

import Foundation

class CommandTester {
    
    static func testJSONCommands() {
        print("=== Flight Command JSON Test ===\n")
        
        let testCommands: [(String, Int)] = [
            ("arm", 1),
            ("hover", 50),
            ("forward", 30),
            ("backward", 25),
            ("left", 20),
            ("right", 20),
            ("hover", 100),
            ("stop", 0),
            ("disarm", 0)
        ]
        
        for (command, value) in testCommands {
            let flightCommand = FlightCommand(command: command, value: value)
            
            do {
                let jsonData = try JSONEncoder().encode(flightCommand)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("Command: \(command)")
                    print("JSON: \(jsonString)")
                    print("Expected ESP32 action: \(getExpectedAction(command, value))")
                    print("---")
                }
            } catch {
                print("Error encoding \(command): \(error)")
            }
        }
        
        print("\n=== RC Channel Mapping Reference ===")
        print("Channel 0 (Roll):     1000=Left,    1500=Center, 2000=Right")
        print("Channel 1 (Pitch):    1000=Back,    1500=Center, 2000=Forward")
        print("Channel 2 (Throttle): 1000=Minimum, 1450=Hover,  2000=Maximum")
        print("Channel 3 (Yaw):      1000=Left,    1500=Center, 2000=Right")
        print("Channel 4 (AUX1):     1000=Disarm,  2000=Armed")
    }
    
    private static func getExpectedAction(_ command: String, _ value: Int) -> String {
        switch command {
        case "arm":
            return "Set AUX1 to 2000 (Armed)"
        case "disarm":
            return "Set AUX1 to 1000 (Disarmed), cut throttle"
        case "hover":
            return "Set throttle to \(1450 + value*2) for \(value)cm hover"
        case "forward":
            return "Set pitch to \(1500 + Int(Double(value)*3.0)) (forward)"
        case "backward":
            return "Set pitch to \(1500 - Int(Double(value)*3.0)) (backward)"
        case "left":
            return "Set roll to \(1500 - Int(Double(value)*3.0)) (left)"
        case "right":
            return "Set roll to \(1500 + Int(Double(value)*3.0)) (right)"
        case "stop":
            return "Emergency stop: all channels to safe values"
        default:
            return "Unknown command"
        }
    }
}

// Test extension for ContentView
extension ContentView {
    func runCommandTests() {
        print("Running command tests...")
        CommandTester.testJSONCommands()
    }
}