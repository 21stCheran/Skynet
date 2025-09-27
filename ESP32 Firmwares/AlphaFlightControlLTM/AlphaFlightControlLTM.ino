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

// --- LTM (Lightweight Telemetry) Frame Types ---
#define LTM_GFRAME 'G'  // GPS Frame (5Hz)
#define LTM_AFRAME 'A'  // Attitude Frame (10Hz)
#define LTM_SFRAME 'S'  // Status Frame (5Hz)
#define LTM_OFRAME 'O'  // Origin Frame (1Hz)  
#define LTM_NFRAME 'N'  // Navigation Frame (~4Hz)
#define LTM_XFRAME 'X'  // GPS Extended Frame (1Hz)

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

// Correct AETR Mapping: [0]Roll, [1]Pitch, [2]Throttle, [3]Yaw, [4]AUX1...
uint16_t rc_channels[8] = {1500, 1500, 1000, 1500, 1000, 1000, 1000, 1000};

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
 * @brief Parse and log LTM telemetry frames for debugging.
 * LTM format: $T<frame_type><payload><checksum>
 */
void parseLTMFrame(uint8_t* buffer, int length) {
    if (length < 4) return; // Minimum LTM frame size
    
    // Check LTM header: $T
    if (buffer[0] != '$' || buffer[1] != 'T') return;
    
    char frameType = buffer[2];
    static unsigned long lastFrameCount[6] = {0}; // Track frame rates
    
    switch(frameType) {
        case LTM_AFRAME: // Attitude Frame (6 bytes payload)
            if (length >= 10) {
                int16_t pitch = buffer[3] | (buffer[4] << 8);
                int16_t roll = buffer[5] | (buffer[6] << 8);  
                int16_t heading = buffer[7] | (buffer[8] << 8);
                lastFrameCount[0]++;
                Serial.printf("LTM-A [%lu]: Pitch=%d° Roll=%d° Heading=%d°\n", 
                             lastFrameCount[0], pitch/10, roll/10, heading);
            }
            break;
            
        case LTM_GFRAME: // GPS Frame (14 bytes payload)
            lastFrameCount[1]++;
            Serial.printf("LTM-G [%lu]: GPS Frame received\n", lastFrameCount[1]);
            break;
            
        case LTM_SFRAME: // Status Frame (7 bytes payload)
            if (length >= 11) {
                uint16_t vbat = buffer[3] | (buffer[4] << 8);
                uint8_t armed = buffer[9] & 0x01;
                lastFrameCount[2]++;
                Serial.printf("LTM-S [%lu]: Vbat=%dmV Armed=%s\n", 
                             lastFrameCount[2], vbat, armed ? "YES" : "NO");
            }
            break;
            
        case LTM_NFRAME: // Navigation Frame
            lastFrameCount[3]++;
            Serial.printf("LTM-N [%lu]: Navigation Frame\n", lastFrameCount[3]);
            break;
            
        case LTM_OFRAME: // Origin Frame  
            lastFrameCount[4]++;
            Serial.printf("LTM-O [%lu]: Origin Frame\n", lastFrameCount[4]);
            break;
            
        case LTM_XFRAME: // GPS Extended Frame
            lastFrameCount[5]++;
            Serial.printf("LTM-X [%lu]: GPS Extended Frame\n", lastFrameCount[5]);
            break;
    }
}

/**
 * @brief LTM (Lightweight Telemetry) automatically streams from INAV.
 * No need to request telemetry - INAV sends it automatically at:
 * - Attitude Frame (A): 10Hz
 * - GPS Frame (G): 5Hz  
 * - Status Frame (S): 5Hz
 * - Navigation Frame (N): ~4Hz
 * - Origin Frame (O): 1Hz
 * - GPS Extended Frame (X): 1Hz
 * 
 * This function is kept for backwards compatibility but does nothing.
 * The FC automatically streams LTM data which is forwarded to iPhone.
 */
void requestTelemetry() {
    // LTM streaming is automatic - no requests needed!
    // INAV continuously sends telemetry frames at high frequency
    
    // Optional: Request additional MSP data that's not in LTM
    static unsigned long lastMspRequest = 0;
    if (millis() - lastMspRequest > 1000) { // Only once per second
        lastMspRequest = millis();
        // Request RAW_IMU if needed for advanced flight control
        // sendMspCommand(MSP_RAW_IMU, NULL, 0);
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
            udp_buffer[len] = '\0'; // Null-terminate for string comparison
            if (strcmp((char*)udp_buffer, "test") == 0) {
                startArmAndThrottleTest();
                udp.beginPacket(clientIp, clientPort);
                udp.print("Motor test initiated! Ensure props are off.");
                udp.endPacket();
            }
            // TODO: Add parsing for JSON RC commands from the app
        }
    }

    // === Part 2: Maintain RC Link Heartbeat (CRITICAL FOR FAILSAFE) ===
    if (rc_link_active && (current_time - last_rc_packet_time > RC_HEARTBEAT_INTERVAL)) {
        last_rc_packet_time = current_time;
        send_msp_set_raw_rc(rc_channels);
    }

    // === Part 3: Handle the Test Sequence State Machine ===
    handleTestSequence();

    // === Part 4: Forward Serial data (LTM/MSP) from FC to iPhone ===
    if (FC_SERIAL.available()) {
        int bytesRead = FC_SERIAL.read(fc_serial_buffer, sizeof(fc_serial_buffer));
        if (bytesRead > 0) {
            // Parse LTM frames for debugging (optional)
            parseLTMFrame(fc_serial_buffer, bytesRead);
            
            // Forward all data to iPhone (LTM + MSP)
            if (clientConnected) {
                udp.beginPacket(clientIp, clientPort);
                udp.write(fc_serial_buffer, bytesRead);
                udp.endPacket();
            }
        }
    }

    // === Part 5: Request Telemetry Periodically ===
    if (clientConnected) {
        requestTelemetry();
    }
}