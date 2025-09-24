# UDP Communication Test Guide

## Testing the iOS App UDP Functionality

### Prerequisites

- Xcode installed with iOS Simulator or physical iPhone
- ESP8266 module programmed with the provided code
- Flight controller connected to ESP8266 (optional for basic testing)

### Test Scenarios

#### 1. Basic UDP Send Test (Without Hardware)

```bash
# On a computer connected to the same network, use netcat to listen
nc -u -l 14550

# Then send a message from the iOS app
# You should see the message appear in the netcat terminal
```

#### 2. UDP Receive Test (Without Hardware)

```bash
# On a computer, send a UDP message to the iPhone's IP
echo "Test message from computer" | nc -u [iPhone_IP] 14550

# The message should appear in the iOS app's message log
```

#### 3. ESP8266 Integration Test

1. Power on ESP8266 with the drone telemetry code
2. Connect iPhone to "Drone_Telemetry" Wi-Fi network
3. Set IP to `192.168.4.1` and port to `14550`
4. Start listening in the iOS app
5. Send a test message - ESP8266 should forward it to flight controller
6. If flight controller is connected and sending MAVLink, messages should appear in log

#### 4. Bidirectional Communication Test

1. Complete ESP8266 integration test setup
2. Connect flight controller to ESP8266 serial port
3. Flight controller MAVLink data should appear in iOS app log
4. Messages sent from iOS app should reach flight controller via ESP8266

### Expected Behavior

#### Successful UDP Send

- Alert shows "Message sent successfully!"
- Message field clears after sending
- ESP8266 forwards message to flight controller

#### Successful UDP Receive

- Messages appear in log with timestamps
- Newest messages at top of list
- No data loss during continuous reception

#### Network Issues

- Alert shows specific error messages
- Connection timeouts handled gracefully
- App remains responsive during network operations

### Debugging Tips

#### iOS App Debug

1. Enable debug logging in Xcode console
2. Check Network framework error messages
3. Verify UserDefaults persistence

#### ESP8266 Debug

1. Monitor serial output for packet forwarding logs
2. Check Wi-Fi access point status
3. Verify UDP port binding

#### Network Debug

1. Use `ping` to verify IP connectivity
2. Use `netstat` to check port usage
3. Use Wireshark to monitor UDP traffic

### Common Test Failures

#### "Failed to send message: Invalid host address"

- Check IP address format (e.g., 192.168.4.1)
- Ensure target device is reachable

#### "Failed to start listening: Address already in use"

- Stop other UDP listeners on the same port
- Choose a different port for testing

#### No messages received

- Verify sender is using correct IP and port
- Check firewall settings on both devices
- Ensure devices are on same network segment
