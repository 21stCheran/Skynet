# Skynet iOS App - UDP Communication

## Overview

The Skynet iOS app now includes full UDP communication capabilities for interfacing with the ESP8266 telemetry bridge. The app can send messages to and receive messages from the drone's ESP8266 module.

## Features

### 1. UDP Message Sending

- Send custom messages to specified IP address and port
- Default settings: IP `192.168.4.1`, Port `14550` (MAVLink standard)
- Real-time feedback on message delivery status

### 2. Persistent Settings

- Automatically saves and restores last used IP address and port
- Settings persist between app launches using UserDefaults

### 3. UDP Message Reception

- Listen for incoming UDP messages on specified port
- Real-time message log with timestamps
- Start/stop listening functionality

### 4. Message Log System

- Displays all received messages with timestamps
- Scrollable log view with newest messages at top
- Clear log functionality

## ESP8266 Integration

The app is designed to work with the ESP8266 bridge module that:

- Creates a Wi-Fi access point named "Drone_Telemetry"
- Listens on port 14550 for UDP packets
- Forwards UDP data to/from the flight controller via serial

### Communication Flow

```
iOS App (UDP) <-> ESP8266 Bridge <-> Flight Controller (Serial/MAVLink)
```

## Usage Instructions

### Initial Setup

1. Connect your iPhone to the "Drone_Telemetry" Wi-Fi network
2. The app will automatically load saved settings (IP: 192.168.4.1, Port: 14550)
3. Tap "Start Listening" to begin receiving messages from the drone

### Sending Messages

1. Ensure IP address and port are correct
2. Enter your message in the text field
3. Tap "Send UDP Data"
4. Monitor the alert for delivery confirmation

### Receiving Messages

1. Tap "Start Listening" to begin monitoring for incoming UDP packets
2. Messages will appear in the log with timestamps
3. Use "Clear" to reset the message log
4. Tap "Stop Listening" when done

## Network Permissions

The app includes the necessary Info.plist entries for local network access:

- `NSLocalNetworkUsageDescription`: Explains why local network access is needed
- `NSBonjourServices`: Declares MAVLink UDP service usage

## Technical Details

### UDP Sender Class

- Uses Apple's Network framework (NWConnection)
- Handles connection state management
- Provides completion callbacks for error handling

### UDP Listener Class

- Uses NWListener for incoming connections
- Supports multiple concurrent connections
- Thread-safe message callbacks

### Data Persistence

- Uses UserDefaults for storing IP/port settings
- Automatic load/save on app lifecycle events

## Troubleshooting

### Common Issues

1. **Cannot send messages**: Check Wi-Fi connection to drone network
2. **No incoming messages**: Ensure correct port and that ESP8266 is powered
3. **Connection timeouts**: Verify IP address matches ESP8266 AP gateway

### Debug Information

- Check Xcode console for detailed connection logs
- Monitor ESP8266 serial output for packet forwarding
- Verify flight controller is sending MAVLink data

## Integration with Flight Controller

The ESP8266 bridge expects:

- Baud rate: 57600 (configurable in ESP8266 code)
- Protocol: MAVLink (binary data)
- Connection: Hardware serial to flight controller

## Future Enhancements

Potential improvements:

- MAVLink message parsing and display
- Connection status indicators
- Automatic IP discovery
- Message filtering and search
- Export log functionality
