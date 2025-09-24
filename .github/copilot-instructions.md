# Skynet Drone Project - AI Copilot Instructions

## Project Overview

Skynet is a disaster response drone system with a hybrid architecture combining hardware flight control with iOS-based autonomous processing. The system uses an iPhone 16 Pro as a companion computer for advanced computer vision, LiDAR mapping, and autonomous flight algorithms.

## Architecture Understanding

### Multi-Component System

- **Hardware Layer**: F450 quadcopter frame with ArduPilot flight controller (STM32F405)
- **iOS App**: Swift/SwiftUI companion computer (`iOS/Skynet/`) for autonomous processing
- **Documentation**: Comprehensive engineering specs in `Documentation/Skynet/`
- **Communication**: MAVLink protocol + ESP32 wireless bridge + custom backend server

### Key Control Flow

```
Computer (Ground Control) <-WebSocket/HTTP-> Backend Server <-MAVLink-> Drone <-ESP32-> iPhone
```

## Development Patterns

### iOS Development (`iOS/Skynet/`)

- Standard SwiftUI app structure with `SkynetApp.swift` as entry point
- Network communication UI in `ContentView.swift` for IP/port-based messaging
- Bundle ID: `com.21C.Skynet.Skynet`, Development Team: `52X7FM2CH3`
- Build using standard Xcode workflows - no custom build scripts

### Documentation Structure (`Documentation/Skynet/`)

- **Architecture.md**: Complete system architecture and communication protocols
- **Avionics/**: Flight controller setup, component specifications, airframe design
- **Physics/Propulsion.md**: Thrust calculations, motor performance data, TWR requirements
- **Components/Material Specsheet/**: Detailed hardware specifications for all components

### Hardware Specifications

- Target AUW: 2kg, TWR: 2:1 minimum (2.3 achieved with current config)
- Motor: A2212 1000KV BLDC with 1045 propellers
- Flight Controller: F4 V3S Plus running ArduPilot firmware
- Power: 3S1P battery system, 30A ESCs
- Telemetry: 2.4GHz NRF24L01+ transceivers

## Critical Workflows

### Component Selection Process

1. Check thrust requirements in `Physics/Propulsion.md` (empirical data table)
2. Verify component compatibility in `Avionics/Airframe Design.md`
3. Update material specs in `Components/Material Specsheet/`

### iOS Development

- Use Xcode for builds - project configured for iPhone deployment
- Network communication follows IP/port pattern (see `ContentView.swift`)
- Consider iPhone 16 Pro capabilities: LiDAR, cameras, processing power

### Documentation Updates

- Hardware changes require updates to both component specs AND physics calculations
- Architecture changes must be reflected in the communication flow diagram
- Always update TWR calculations when changing propulsion components

## Project-Specific Conventions

### File Organization

- Component specs use full descriptive names with spaces and special characters
- Physics documentation includes empirical test data with source attribution
- iOS code follows standard Apple conventions (no custom patterns yet)

### Communication Protocols

- MAVLink for drone-to-ground control communication
- ESP32 bridge for iPhone-to-drone local communication
- WebSocket/HTTP for ground control interface

### Hardware Integration Points

- iPhone as primary autonomous processor (not just controller)
- ArduPilot firmware expected on flight controller
- Custom backend server required for multi-device coordination

## Key Files for Context

- `Documentation/Skynet/Avionics/Architecture.md`: Complete system design
- `Documentation/Skynet/Physics/Propulsion.md`: Performance calculations
- `iOS/Skynet/Skynet/ContentView.swift`: Current iOS networking implementation
- `Documentation/Skynet/Avionics/Airframe Design.md`: Component specifications
