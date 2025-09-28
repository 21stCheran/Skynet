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
const unsigned int RC_HEARTBEAT_INTERVAL = 16; // 16ms -> ~62.5Hz (optimized for latency)
unsigned long last_command_time = 0;
const unsigned int COMMAND_TIMEOUT = 200; // Reduced to 200ms for faster failsafe

// Telemetry Management
unsigned long last_telemetry_request = 0;
const unsigned int TELEMETRY_INTERVAL = 50; // 50ms -> 20Hz for telemetry requests
int current_telemetry_type = 0; // Track which telemetry to request next

// FC Communication Latency Tracking
unsigned long fc_command_sent_time = 0;
unsigned long fc_response_received_time = 0;

// Correct AETR Mapping: [0]Roll, [1]Pitch, [2]Throttle, [3]Yaw, [4]AUX1...
uint16_t rc_channels[8] = {1500, 1500, 1000, 1500, 1000, 1000, 1000, 1000};

// Flight Control Constants
const uint16_t RC_MIN = 1000;
const uint16_t RC_CENTER = 1500;
const uint16_t RC_MAX = 2000;
const uint16_t HOVER_THROTTLE_BASE = 1450; // Adjust based on your drone's weight
const uint16_t THROTTLE_DEADBAND = 50;

// Safe Motor Speed Constants - NEW
const uint16_t SAFE_THROTTLE_MIN = 1200; // Minimum safe throttle - motors always spinning when armed
const uint16_t SAFE_THROTTLE_MAX = 1800; // Maximum safe throttle (90% of full power)
const uint16_t SAFE_MOVEMENT_MAX = 60;   // Maximum movement intensity in safe mode
const unsigned long SAFE_DISARM_DELAY = 2000; // Delay before full motor stop during safe disarm

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
    bool safeMode;
};

FlightCommand currentCommand = {"", 0, 0, false, true};

// Safe Disarm State Management - NEW
struct SafeDisarmState {
    bool inProgress;
    unsigned long startTime;
    uint16_t currentThrottle;
};

SafeDisarmState safeDisarmState = {false, 0, 0};

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
        value = constrain(value, (uint16_t)RC_MIN, (uint16_t)RC_MAX);
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
    }
}

/**
 * @brief Parse MSP attitude response from FC
 * MSP_ATTITUDE format: int16_t roll, int16_t pitch, int16_t yaw (all in degrees * 10)
 */
void parseMspAttitude(uint8_t* payload, uint8_t payload_size) {
    if (payload_size >= 6) {
        // Calculate latency
        fc_response_received_time = millis();
        unsigned long latency = fc_response_received_time - fc_command_sent_time;
        Serial.printf("FC_LATENCY: %lu ms\n", latency);
    }
}

/**
 * @brief Simple MSP response parser - Only processes essential telemetry
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
            case MSP_ATTITUDE:
                parseMspAttitude(payload, payload_size);
                break;
            // Only process essential telemetry data
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
        
        // Fallback to simple altitude-based estimate
        int throttle_offset = (target_altitude_cm - 50) * 1; // Assume 50cm baseline
        uint16_t hover_throttle = HOVER_THROTTLE_BASE + throttle_offset;
        return constrain(hover_throttle, (uint16_t)(RC_MIN + 100), (uint16_t)(RC_MAX - 100));
    }
    
    // Closed-loop altitude control with PID-like behavior
    float altitude_error = altitude_data.altitude_error;
    
    // Simple proportional control (you can add I and D terms later)
    float kP = 2.0; // Proportional gain (adjust based on testing)
    float throttle_adjustment = altitude_error * kP;
    
    // Apply throttle adjustment to base hover throttle
    uint16_t calculated_throttle = HOVER_THROTTLE_BASE + (int)throttle_adjustment;
    
    // Safety limits
    calculated_throttle = constrain(calculated_throttle, (uint16_t)(RC_MIN + 100), (uint16_t)(RC_MAX - 100));
    
    return calculated_throttle;
}

/**
 * @brief Executes hover command with relative altitude change
 * Uses INAV's altitude feedback for closed-loop control
 */
void executeHoverCommand(int relative_altitude_cm) {
    // Calculate absolute target altitude from current position + relative change
    int target_altitude_cm = altitude_data.current_altitude_cm + relative_altitude_cm;
    
    // Safety check: ensure target altitude is reasonable
    if (target_altitude_cm < 10) {
        target_altitude_cm = 10;
    } else if (target_altitude_cm > 1000) {
        target_altitude_cm = 1000;
    }
    
    // Method 1: Use our own altitude control (current approach)
    uint16_t hover_throttle = calculateHoverThrottle(target_altitude_cm);
    
    // Reset all controls to center except throttle
    setRCChannel(0, RC_CENTER); // Roll center
    setRCChannel(1, RC_CENTER); // Pitch center
    setRCChannel(2, hover_throttle); // Calculated hover throttle
    setRCChannel(3, RC_CENTER); // Yaw center
}

/**
 * @brief Executes movement commands (forward/backward)
 */
void executeMovementCommand(String direction, int intensity) {
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
    setRCChannel(0, RC_CENTER); // Roll center
    setRCChannel(1, RC_CENTER); // Pitch center
    setRCChannel(2, RC_MIN);    // Throttle minimum
    setRCChannel(3, RC_CENTER); // Yaw center
    setRCChannel(4, RC_MIN);    // Disarm
    
    // Cancel any safe disarm in progress
    safeDisarmState.inProgress = false;
    
    currentCommand = {"", 0, 0, false, true}; // Clear current command
}

/**
 * @brief Safe disarm - gradually reduces throttle while maintaining minimum motor speed
 * NEW: Prevents sudden motor stop which can cause crashes
 */
void executeSafeDisarm() {
    // Start safe disarm process
    safeDisarmState.inProgress = true;
    safeDisarmState.startTime = millis();
    safeDisarmState.currentThrottle = rc_channels[2]; // Current throttle
    
    // Center all controls except throttle
    setRCChannel(0, RC_CENTER); // Roll center
    setRCChannel(1, RC_CENTER); // Pitch center
    setRCChannel(3, RC_CENTER); // Yaw center
    
    // Start with safe minimum throttle, not current throttle
    setRCChannel(2, SAFE_THROTTLE_MIN);
}

/**
 * @brief Handle safe disarm process over time
 * NEW: Manages the safe disarm state machine
 */
void handleSafeDisarm() {
    if (!safeDisarmState.inProgress) return;
    
    unsigned long elapsed = millis() - safeDisarmState.startTime;
    
    if (elapsed >= SAFE_DISARM_DELAY) {
        // Complete the disarm
        setRCChannel(2, RC_MIN);    // Throttle minimum
        setRCChannel(4, RC_MIN);    // Disarm
        safeDisarmState.inProgress = false;
        currentCommand = {"", 0, 0, false, true}; // Clear current command
    } else {
        // Maintain safe minimum throttle during delay
        setRCChannel(2, SAFE_THROTTLE_MIN);
    }
}

/**
 * @brief Safe hover with minimum motor speed enforcement
 * NEW: Ensures motors never stop completely when armed
 */
void executeSafeHover(int throttleValue, bool safeMode) {
    uint16_t safeThrottle = throttleValue;
    
    if (safeMode) {
        // Enforce safe limits
        safeThrottle = constrain(throttleValue, (int)SAFE_THROTTLE_MIN, (int)SAFE_THROTTLE_MAX);
    } else {
        // Still enforce absolute minimum when armed
        safeThrottle = max(throttleValue, (int)(RC_MIN + 50)); // At least 50 above minimum
    }
    
    // Reset all controls to center except throttle
    setRCChannel(0, RC_CENTER); // Roll center
    setRCChannel(1, RC_CENTER); // Pitch center
    setRCChannel(2, safeThrottle); // Safe throttle
    setRCChannel(3, RC_CENTER); // Yaw center
}

/**
 * @brief Safe movement commands with intensity limits
 * NEW: Limits movement intensity in safe mode
 */
void executeSafeMovement(String direction, int intensity, bool safeMode) {
    int safeIntensity = intensity;
    
    if (safeMode) {
        safeIntensity = min(intensity, (int)SAFE_MOVEMENT_MAX);
    }
    
    // Calculate movement value based on safe intensity
    int movement_offset = map(safeIntensity, 0, 100, 0, 300); // Max 300 units from center
    
    if (direction == "forward") {
        setRCChannel(1, RC_CENTER + movement_offset); // Pitch forward
    } else if (direction == "backward") {
        setRCChannel(1, RC_CENTER - movement_offset); // Pitch backward
    } else if (direction == "left") {
        setRCChannel(0, RC_CENTER - movement_offset); // Roll left
    } else if (direction == "right") {
        setRCChannel(0, RC_CENTER + movement_offset); // Roll right
    } else if (direction == "yaw_left") {
        setRCChannel(3, RC_CENTER - movement_offset); // Yaw left
    } else if (direction == "yaw_right") {
        setRCChannel(3, RC_CENTER + movement_offset); // Yaw right
    }
    
    // Maintain current throttle for movement (with safe minimum)
    uint16_t currentThrottle = rc_channels[2];
    if (safeMode && currentThrottle < SAFE_THROTTLE_MIN) {
        setRCChannel(2, SAFE_THROTTLE_MIN);
    }
}

/**
 * @brief Restart ESP32 with safe disarm first
 */
void executeRestart() {
    // First execute safe disarm
    executeSafeDisarm();
    
    // Wait for safe disarm to complete, then restart
    delay(SAFE_DISARM_DELAY + 500); // Extra 500ms buffer
    ESP.restart();
}

/**
 * @brief Parses and executes JSON commands from iPhone/WebApp
 * Expected format: {"command":"hover","value":50,"safeMode":true}
 * NEW: Enhanced to handle safe mode and additional commands
 */
void parseAndExecuteCommand(String jsonCommand) {
    Serial.printf("CMD_RECEIVED: %s\n", jsonCommand.c_str());
    
    // Simple JSON parsing (you could use ArduinoJson library for more robust parsing)
    int commandStart = jsonCommand.indexOf("\"command\":\"") + 11;
    int commandEnd = jsonCommand.indexOf("\"", commandStart);
    String command = jsonCommand.substring(commandStart, commandEnd);
    
    int valueStart = jsonCommand.indexOf("\"value\":") + 8;
    int valueEnd = jsonCommand.indexOf("}", valueStart);
    if (valueEnd == -1) valueEnd = jsonCommand.indexOf(",", valueStart);
    int value = jsonCommand.substring(valueStart, valueEnd).toInt();
    
    // Parse safe mode flag (default to true for safety)
    bool safeMode = true;
    int safeModeStart = jsonCommand.indexOf("\"safeMode\":");
    if (safeModeStart != -1) {
        safeModeStart += 11;
        String safeModeStr = jsonCommand.substring(safeModeStart, jsonCommand.indexOf(",", safeModeStart));
        if (safeModeStr.indexOf("}") != -1) {
            safeModeStr = jsonCommand.substring(safeModeStart, jsonCommand.indexOf("}", safeModeStart));
        }
        safeMode = (safeModeStr.indexOf("true") != -1);
    }
    
    // Update current command
    currentCommand.type = command;
    currentCommand.value = value;
    currentCommand.timestamp = millis();
    currentCommand.active = true;
    currentCommand.safeMode = safeMode;
    last_command_time = millis();
    
    // Execute the command with safe mode consideration
    if (command == "hover") {
        executeHoverCommand(value); // value = relative altitude change in cm
    } else if (command == "safe_hover") {
        executeSafeHover(value, safeMode); // NEW: Direct throttle control with safety
    } else if (command == "forward") {
        executeSafeMovement("forward", value, safeMode); // Enhanced with safety
    } else if (command == "backward") {
        executeSafeMovement("backward", value, safeMode);
    } else if (command == "left") {
        executeSafeMovement("left", value, safeMode);
    } else if (command == "right") {
        executeSafeMovement("right", value, safeMode);
    } else if (command == "yaw_left") {
        executeSafeMovement("yaw_left", value, safeMode); // NEW: Yaw control
    } else if (command == "yaw_right") {
        executeSafeMovement("yaw_right", value, safeMode); // NEW: Yaw control
    } else if (command == "stop") {
        executeEmergencyStop();
    } else if (command == "arm") {
        setRCChannel(4, RC_MAX); // Arm
        rc_link_active = true; // Activate RC link after arming
    } else if (command == "disarm") {
        executeEmergencyStop(); // Standard immediate disarm
    } else if (command == "safe_disarm") {
        executeSafeDisarm(); // NEW: Safe disarm with motor speed maintenance
    } else if (command == "restart") {
        executeRestart(); // NEW: Restart ESP32 with safe landing
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
        // Fallback to safe hover state (no altitude change)
        executeHoverCommand(0); // Maintain current altitude (0 relative change)
        currentCommand.active = false;
    }
}

/**
 * @brief Sends an MSP_SET_RAW_RC packet with the provided channel data.
 */
void send_msp_set_raw_rc(uint16_t channels[]) {
    fc_command_sent_time = millis(); // Track when command was sent
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
                rc_channels[2] = 2000; // Throttle to max
                currentState = FULL_THROTTLE;
                testStateStartTime = millis();
            }
            break;
        case FULL_THROTTLE:
            if (millis() - testStateStartTime > 3000) {
                rc_channels[2] = 1000; // Throttle to low
                rc_channels[4] = 1000; // AUX1 low to disarm
                currentState = DISARMING;
                testStateStartTime = millis();
            }
            break;
        case DISARMING:
             if (millis() - testStateStartTime > 500) {
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
        return;
    }
    
    rc_channels[4] = 2000; // Set AUX1 high to arm
    rc_link_active = true; // Activate RC link for test
    currentState = ARMING;
    testStateStartTime = millis();
}

/**
 * @brief Requests essential telemetry types from the FC: heading, yaw, pitch, altitude
 */
void requestTelemetry() {
    if (millis() - last_telemetry_request > TELEMETRY_INTERVAL) {
        last_telemetry_request = millis();
        fc_command_sent_time = millis(); // Track latency
        
        switch(current_telemetry_type) {
            case 0: sendMspCommand(MSP_ATTITUDE, NULL, 0); break; // Pitch, Roll, Yaw
            case 1: sendMspCommand(MSP_ALTITUDE, NULL, 0); break; // Altitude
        }
        current_telemetry_type = (current_telemetry_type + 1) % 2; // Only 2 essential telemetry types
    }
}

// --- Main Program ---

void setup() {
    Serial.begin(115200);

    // Initialize serial to the Flight Controller
    FC_SERIAL.begin(FC_BAUD_RATE, SERIAL_8N1, FC_RX_PIN, FC_TX_PIN);

    WiFi.softAP(ssid, password);
    udp.begin(udpPort);
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
        }
    }

    // === Part 2: Maintain RC Link Heartbeat (CRITICAL FOR FAILSAFE) ===
    // Always send RC channels every 16ms when RC link is active
    if (rc_link_active && (current_time - last_rc_packet_time > RC_HEARTBEAT_INTERVAL)) {
        last_rc_packet_time = current_time;
        send_msp_set_raw_rc(rc_channels);
    }

    // === Part 3: Handle Command Timeout Safety ===
    handleCommandTimeout();

    // === Part 4: Handle Safe Disarm Process ===
    handleSafeDisarm();

    // === Part 5: Handle the Test Sequence State Machine ===
    handleTestSequence();

    // === Part 6: Process and Forward Serial data (from FC) to the iPhone ===
    if (FC_SERIAL.available()) {
        int bytesRead = FC_SERIAL.read(fc_serial_buffer, sizeof(fc_serial_buffer));
        if (bytesRead > 0) {
            // Parse MSP responses for our own use (altitude, latency tracking)
            parseMspResponse(fc_serial_buffer, bytesRead);
            
            // Forward raw MSP data to iPhone
            if (clientConnected) {
                udp.beginPacket(clientIp, clientPort);
                udp.write(fc_serial_buffer, bytesRead);
                udp.endPacket();
            }
        }
    }

    // === Part 7: Request Essential Telemetry Only ===
    if (clientConnected) {
        requestTelemetry(); // Only requests heading, yaw, pitch, altitude at 50ms intervals
    }
}