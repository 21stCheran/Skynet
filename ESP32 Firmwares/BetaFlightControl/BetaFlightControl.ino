#include <WiFi.h>
#include <WiFiUdp.h>
#include <string.h>

// --- Wi-Fi Settings ---
const char *ssid = "INAV_Bridge_Network";
const char *password = "drone12345";

// --- UDP Settings ---
unsigned int udpPort = 14550;

// --- Serial Bridge Settings ---
HardwareSerial FC_SERIAL(2); // Use UART port 2
#define FC_BAUD_RATE 115200
#define FC_RX_PIN 25 // Connect to FC TX
#define FC_TX_PIN 26 // Connect to FC RX

// --- MSP Command Constants ---
#define MSP_SET_RAW_RC 200
#define MSP_RC 105
#define MSP_ATTITUDE 108
#define MSP_ALTITUDE 109
#define MSP_RAW_GPS 106
#define MSP_STATUS 101
#define MSP_RAW_IMU 102

// --- Global Variables ---
WiFiUDP udp;
IPAddress clientIp;
int clientPort;
bool clientConnected = false;

// Buffers
uint8_t udp_buffer[256];
uint8_t fc_serial_buffer[256];

// RC Link Management
bool rc_link_active = false;
unsigned long last_rc_packet_time = 0;
const unsigned int RC_HEARTBEAT_INTERVAL = 20; // 20ms -> 50Hz
unsigned long last_command_time = 0;
const unsigned int COMMAND_TIMEOUT = 500; // 500ms timeout for commands

// Correct AETR Mapping: [0]Roll, [1]Pitch, [2]Throttle, [3]Yaw, [4]AUX1...
uint16_t rc_channels[8] = {1500, 1500, 1000, 1500, 1000, 1000, 1000, 1000};

// Flight Control Constants
const uint16_t RC_MIN = 1000;
const uint16_t RC_CENTER = 1500;
const uint16_t RC_MAX = 2000;
const uint16_t HOVER_THROTTLE_BASE = 1450; // Adjust based on your drone's weight
const uint16_t THROTTLE_DEADBAND = 50;

// Altitude Control Constants
struct AltitudeData {
    int32_t current_altitude_cm = 0;    // Current altitude from INAV
    int32_t target_altitude_cm = 0;     // Target altitude from phone
    bool altitude_valid = false;        // Whether we have valid altitude data
    unsigned long last_altitude_update = 0;
    float altitude_error = 0.0;         // Target - Current
};

AltitudeData altitude_data;

// Command State Management
struct FlightCommand {
    String type;
    int value;
    unsigned long timestamp;
    bool active;
};

FlightCommand currentCommand = {"", 0, 0, false};

// --- Test Sequence State Machine ---
enum TestState { IDLE, ARMING, FULL_THROTTLE, DISARMING, TEST_COMPLETE };
TestState currentState = IDLE;
unsigned long testStateStartTime = 0;


/**
 * @brief Calculates the MSP checksum.
 */
uint8_t calculateMspChecksum(uint8_t payload_size, uint8_t command, uint8_t *payload) {
    uint8_t checksum = 0;
    checksum ^= payload_size;
    checksum ^= command;
    for (int i = 0; i < payload_size; i++) {
        checksum ^= payload[i];
    }
    return checksum;
}

/**
 * @brief Constructs and sends a generic MSP command to the flight controller.
 */
void sendMspCommand(uint8_t command, uint8_t *payload, uint8_t payload_size) {
    uint8_t packet[payload_size + 6];
    packet[0] = '$';
    packet[1] = 'M';
    packet[2] = '<';
    packet[3] = payload_size;
    packet[4] = command;
    if (payload_size > 0) {
        memcpy(&packet[5], payload, payload_size);
    }
    packet[payload_size + 5] = calculateMspChecksum(payload_size, command, payload);
    FC_SERIAL.write(packet, sizeof(packet));
}

/**
 * @brief Safely sets RC channel values with bounds checking
 */
void setRCChannel(int channel, uint16_t value) {
    if (channel >= 0 && channel < 8) {
        value = constrain(value, RC_MIN, RC_MAX);
        rc_channels[channel] = value;
    }
}

/**
 * @brief Parse MSP altitude response from INAV
 * MSP_ALTITUDE format: int32_t altitude (cm), int16_t velocity (cm/s)
 */
void parseMspAltitude(uint8_t* payload, uint8_t payload_size) {
    if (payload_size >= 4) {
        // Extract altitude as int32_t (little-endian)
        altitude_data.current_altitude_cm = (int32_t)(
            payload[0] | 
            (payload[1] << 8) | 
            (payload[2] << 16) | 
            (payload[3] << 24)
        );
        altitude_data.altitude_valid = true;
        altitude_data.last_altitude_update = millis();
        
        // Calculate error for control
        altitude_data.altitude_error = altitude_data.target_altitude_cm - altitude_data.current_altitude_cm;
        
        Serial.printf("ALTITUDE: Current=%d cm, Target=%d cm, Error=%.1f cm\n", 
                     altitude_data.current_altitude_cm, 
                     altitude_data.target_altitude_cm,
                     altitude_data.altitude_error);
    }
}

/**
 * @brief Simple MSP response parser
 */
void parseMspResponse(uint8_t* buffer, int length) {
    if (length < 6) return; // Minimum MSP packet size
    
    // Check for MSP response header: $M>
    if (buffer[0] == '$' && buffer[1] == 'M' && buffer[2] == '>') {
        uint8_t payload_size = buffer[3];
        uint8_t command = buffer[4];
        uint8_t* payload = &buffer[5];
        
        switch (command) {
            case MSP_ALTITUDE:
                parseMspAltitude(payload, payload_size);
                break;
            // Add other MSP response handlers here
            default:
                break;
        }
    }
}

/**
 * @brief Calculates hover throttle using closed-loop altitude control
 * Now uses actual altitude feedback from INAV!
 */
uint16_t calculateHoverThrottle(int target_altitude_cm) {
    altitude_data.target_altitude_cm = target_altitude_cm;
    
    // If we don't have valid altitude data, use open-loop estimate
    if (!altitude_data.altitude_valid || 
        (millis() - altitude_data.last_altitude_update > 1000)) {
        
        Serial.println("WARNING: No altitude data - using open-loop control");
        // Fallback to simple altitude-based estimate
        int throttle_offset = (target_altitude_cm - 50) * 1; // Assume 50cm baseline
        uint16_t hover_throttle = HOVER_THROTTLE_BASE + throttle_offset;
        return constrain(hover_throttle, RC_MIN + 100, RC_MAX - 100);
    }
    
    // Closed-loop altitude control with PID-like behavior
    float altitude_error = altitude_data.altitude_error;
    
    // Simple proportional control (you can add I and D terms later)
    float kP = 2.0; // Proportional gain (adjust based on testing)
    float throttle_adjustment = altitude_error * kP;
    
    // Apply throttle adjustment to base hover throttle
    uint16_t calculated_throttle = HOVER_THROTTLE_BASE + (int)throttle_adjustment;
    
    // Safety limits
    calculated_throttle = constrain(calculated_throttle, RC_MIN + 100, RC_MAX - 100);
    
    Serial.printf("THROTTLE: Base=%d, Adjustment=%.1f, Final=%d\n", 
                 HOVER_THROTTLE_BASE, throttle_adjustment, calculated_throttle);
    
    return calculated_throttle;
}

/**
 * @brief Executes hover command at specified altitude
 * Uses INAV's altitude feedback for closed-loop control
 */
void executeHoverCommand(int altitude_cm) {
    Serial.printf("HOVER: Executing hover at %d cm\n", altitude_cm);
    
    // Method 1: Use our own altitude control (current approach)
    uint16_t hover_throttle = calculateHoverThrottle(altitude_cm);
    
    // Reset all controls to center except throttle
    setRCChannel(0, RC_CENTER); // Roll center
    setRCChannel(1, RC_CENTER); // Pitch center
    setRCChannel(2, hover_throttle); // Calculated hover throttle
    setRCChannel(3, RC_CENTER); // Yaw center
    
    // TODO: Method 2 - Use INAV's ALTHOLD mode (better approach)
    // This would involve setting AUX channels to activate ALTHOLD mode
    // and letting INAV handle altitude maintenance automatically
    
    Serial.printf("HOVER: Throttle set to %d (Current alt: %d cm)\n", 
                 hover_throttle, altitude_data.current_altitude_cm);
}

/**
 * @brief Executes movement commands (forward/backward)
 */
void executeMovementCommand(String direction, int intensity) {
    Serial.printf("MOVEMENT: %s with intensity %d\n", direction.c_str(), intensity);
    
    // Calculate movement value based on intensity (0-100)
    int movement_offset = map(intensity, 0, 100, 0, 300); // Max 300 units from center
    
    if (direction == "forward") {
        setRCChannel(1, RC_CENTER + movement_offset); // Pitch forward
    } else if (direction == "backward") {
        setRCChannel(1, RC_CENTER - movement_offset); // Pitch backward
    } else if (direction == "left") {
        setRCChannel(0, RC_CENTER - movement_offset); // Roll left
    } else if (direction == "right") {
        setRCChannel(0, RC_CENTER + movement_offset); // Roll right
    }
    
    // Maintain current throttle for movement
    // Keep yaw centered unless specified
    setRCChannel(3, RC_CENTER);
}

/**
 * @brief Emergency stop - cuts throttle and centers controls
 */
void executeEmergencyStop() {
    Serial.println("EMERGENCY: Executing emergency stop!");
    
    setRCChannel(0, RC_CENTER); // Roll center
    setRCChannel(1, RC_CENTER); // Pitch center
    setRCChannel(2, RC_MIN);    // Throttle minimum
    setRCChannel(3, RC_CENTER); // Yaw center
    setRCChannel(4, RC_MIN);    // Disarm
    
    currentCommand = {"", 0, 0, false}; // Clear current command
}

/**
 * @brief Parses and executes JSON commands from iPhone
 * Expected format: {"command":"hover","value":50}
 */
void parseAndExecuteCommand(String jsonCommand) {
    Serial.println("Parsing command: " + jsonCommand);
    
    // Simple JSON parsing (you could use ArduinoJson library for more robust parsing)
    int commandStart = jsonCommand.indexOf("\"command\":\"") + 11;
    int commandEnd = jsonCommand.indexOf("\"", commandStart);
    String command = jsonCommand.substring(commandStart, commandEnd);
    
    int valueStart = jsonCommand.indexOf("\"value\":") + 8;
    int valueEnd = jsonCommand.indexOf("}", valueStart);
    if (valueEnd == -1) valueEnd = jsonCommand.indexOf(",", valueStart);
    int value = jsonCommand.substring(valueStart, valueEnd).toInt();
    
    // Update current command
    currentCommand.type = command;
    currentCommand.value = value;
    currentCommand.timestamp = millis();
    currentCommand.active = true;
    last_command_time = millis();
    
    // Execute the command
    if (command == "hover") {
        executeHoverCommand(value); // value = altitude in cm
    } else if (command == "forward") {
        executeMovementCommand("forward", value); // value = intensity 0-100
    } else if (command == "backward") {
        executeMovementCommand("backward", value);
    } else if (command == "left") {
        executeMovementCommand("left", value);
    } else if (command == "right") {
        executeMovementCommand("right", value);
    } else if (command == "stop") {
        executeEmergencyStop();
    } else if (command == "arm") {
        setRCChannel(4, RC_MAX); // Arm
        Serial.println("ARMING: Drone armed");
    } else if (command == "disarm") {
        setRCChannel(4, RC_MIN); // Disarm
        executeEmergencyStop();
        Serial.println("DISARMING: Drone disarmed");
    } else {
        Serial.println("Unknown command: " + command);
    }
    
    // Send acknowledgment back to iPhone
    if (clientConnected) {
        String response = "{\"status\":\"executed\",\"command\":\"" + command + "\",\"value\":" + value + "}";
        udp.beginPacket(clientIp, clientPort);
        udp.print(response);
        udp.endPacket();
    }
}

/**
 * @brief Handles command timeout and safety fallback
 */
void handleCommandTimeout() {
    if (currentCommand.active && (millis() - last_command_time > COMMAND_TIMEOUT)) {
        Serial.println("SAFETY: Command timeout - returning to hover");
        
        // Fallback to safe hover state
        executeHoverCommand(50); // Default 50cm hover
        currentCommand.active = false;
    }
}

/**
 * @brief Sends an MSP_SET_RAW_RC packet with the provided channel data.
 */
void send_msp_set_raw_rc(uint16_t channels[]) {
    uint8_t payload_size = 16; // 8 channels * 2 bytes/channel
    // Cast the uint16_t array to a uint8_t pointer to send as payload
    sendMspCommand(MSP_SET_RAW_RC, (uint8_t*)channels, payload_size);
}

/**
 * @brief Manages the non-blocking test sequence using a state machine.
 * This is called from the main loop.
 */
void handleTestSequence() {
    if (currentState == IDLE || currentState == TEST_COMPLETE) {
        return; // Do nothing if the test is not running or has finished
    }

    switch (currentState) {
        case ARMING:
            if (millis() - testStateStartTime > 500) {
                Serial.println("TEST: FULL THROTTLE...");
                rc_channels[2] = 2000; // Throttle to max
                currentState = FULL_THROTTLE;
                testStateStartTime = millis();
            }
            break;
        case FULL_THROTTLE:
            if (millis() - testStateStartTime > 3000) {
                Serial.println("TEST: DISARMING...");
                rc_channels[2] = 1000; // Throttle to low
                rc_channels[4] = 1000; // AUX1 low to disarm
                currentState = DISARMING;
                testStateStartTime = millis();
            }
            break;
        case DISARMING:
             if (millis() - testStateStartTime > 500) {
                Serial.println("TEST: COMPLETE.");
                currentState = TEST_COMPLETE;
             }
            break;
        default:
            break;
    }
}

/**
 * @brief Kicks off the arm-and-throttle test sequence.
 */
void startArmAndThrottleTest() {
    if (currentState != IDLE && currentState != TEST_COMPLETE) {
        Serial.println("Test already in progress.");
        return;
    }
    Serial.println("\nReceived 'test' command! Starting sequence.");
    Serial.println("!!! ENSURE PROPELLERS ARE REMOVED !!!");
    
    Serial.println("TEST: ARMING...");
    rc_channels[4] = 2000; // Set AUX1 high to arm
    currentState = ARMING;
    testStateStartTime = millis();
}

/**
 * @brief Requests different telemetry types from the FC in a cycle.
 */
void requestTelemetry() {
    static unsigned long lastRequestTime = 0;
    static int telemetryState = 0;
    
    if (millis() - lastRequestTime > 100) { // Cycle through requests every 100ms
        lastRequestTime = millis();
        switch(telemetryState) {
            case 0: sendMspCommand(MSP_ATTITUDE, NULL, 0); break;
            case 1: sendMspCommand(MSP_STATUS, NULL, 0); break;
            case 2: sendMspCommand(MSP_RAW_GPS, NULL, 0); break;
            case 3: sendMspCommand(MSP_ALTITUDE, NULL, 0); break;
        }
        telemetryState = (telemetryState + 1) % 4; // Move to the next state
    }
}

// --- Main Program ---

void setup() {
    // FIX: Corrected baud rate typo from 1152200 to 115200
    Serial.begin(115200);
    Serial.println("\nINAV Serial-to-UDP Bridge Initializing...");

    // Initialize serial to the Flight Controller. Serial2's default pins are 16(RX)/17(TX),
    // but the ESP32 allows remapping them to any suitable GPIOs, like 25 and 26.
    FC_SERIAL.begin(FC_BAUD_RATE, SERIAL_8N1, FC_RX_PIN, FC_TX_PIN);
    Serial.printf("FC Serial started on RX:%d, TX:%d\n", FC_RX_PIN, FC_TX_PIN);

    WiFi.softAP(ssid, password);
    IPAddress myIP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(myIP);

    udp.begin(udpPort);
    Serial.print("Listening for UDP on port ");
    Serial.println(udpPort);
}

void loop() {
    unsigned long current_time = millis();

    // === Part 1: Handle Incoming Commands from Client (iPhone) ===
    int packetSize = udp.parsePacket();
    if (packetSize > 0) {
        if (!clientConnected) {
            clientIp = udp.remoteIP();
            clientPort = udp.remotePort();
            clientConnected = true;
            rc_link_active = true; // Activate the RC link heartbeat
            Serial.print("Client connected: ");
            Serial.println(clientIp);
        }

        int len = udp.read(udp_buffer, sizeof(udp_buffer));
        if (len > 0) {
            udp_buffer[len] = '\0'; // Null-terminate for string processing
            String receivedData = String((char*)udp_buffer);
            
            // Handle legacy test command
            if (receivedData == "test") {
                startArmAndThrottleTest();
                udp.beginPacket(clientIp, clientPort);
                udp.print("Motor test initiated! Ensure props are off.");
                udp.endPacket();
            }
            // Handle JSON commands
            else if (receivedData.startsWith("{") && receivedData.endsWith("}")) {
                parseAndExecuteCommand(receivedData);
            }
            // Handle simple string commands for backward compatibility
            else {
                Serial.println("Received non-JSON command: " + receivedData);
                if (clientConnected) {
                    udp.beginPacket(clientIp, clientPort);
                    udp.print("Error: Use JSON format - {\"command\":\"hover\",\"value\":50}");
                    udp.endPacket();
                }
            }
        }
    }

    // === Part 2: Maintain RC Link Heartbeat (CRITICAL FOR FAILSAFE) ===
    if (rc_link_active && (current_time - last_rc_packet_time > RC_HEARTBEAT_INTERVAL)) {
        last_rc_packet_time = current_time;
        send_msp_set_raw_rc(rc_channels);
    }

    // === Part 3: Handle Command Timeout Safety ===
    handleCommandTimeout();

    // === Part 4: Handle the Test Sequence State Machine ===
    handleTestSequence();

    // === Part 5: Process and Forward Serial data (from FC) to the iPhone ===
    if (FC_SERIAL.available()) {
        int bytesRead = FC_SERIAL.read(fc_serial_buffer, sizeof(fc_serial_buffer));
        if (bytesRead > 0) {
            // Parse MSP responses for our own use (altitude, etc.)
            parseMspResponse(fc_serial_buffer, bytesRead);
            
            // Forward raw data to iPhone
            if (clientConnected) {
                udp.beginPacket(clientIp, clientPort);
                udp.write(fc_serial_buffer, bytesRead);
                udp.endPacket();
            }
        }
    }

    // === Part 6: Request Telemetry Periodically ===
    if (clientConnected) {
        requestTelemetry();
    }
}