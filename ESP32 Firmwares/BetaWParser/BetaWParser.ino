#include <WiFi.h>
#include <WiFiUdp.h>
#include <string.h>

// --- Wi-Fi Settings ---
const char *ssid = "INAV_Bridge_Network";
const char *password = "drone12345";

// --- UDP Settings ---
unsigned int udpPort = 14550; // The port your iPhone app will send to and listen on

// --- Serial Bridge Settings ---
// Using GPIO4 (RX) and GPIO2 (TX) instead of default Serial2 pins (16/17)
// These pins were verified to work in loopback test
HardwareSerial FC_SERIAL(2); // Use Serial2 but with custom pins
#define FC_BAUD_RATE 115200 // Must match the baud rate set in INAV

// --- Global Variables ---
WiFiUDP udp;
IPAddress clientIp; // Will store the IP address of your iPhone
int clientPort;     // Will store the port of your iPhone app
bool clientConnected = false;

// Buffers for data forwarding
uint8_t serial_buffer[256];
uint8_t udp_buffer[256];

// MSP packet parsing variables
uint8_t msp_buffer[256];
int msp_buffer_pos = 0;
bool msp_packet_ready = false;

// Global packet counter for statistics
int packetsPerSecond = 0;

// Function to send formatted JSON data to iPhone
void sendFormattedData(String jsonData) {
  if (clientConnected) {
    udp.beginPacket(clientIp, clientPort);
    udp.print(jsonData);
    udp.endPacket();
  }
}

// Function to parse MSP packets and extract readable data
void parseMSPPacket(uint8_t* data, int length) {
  if (length < 6) return; // Minimum MSP packet size
  
  // Check MSP header: $M>
  if (data[0] != 0x24 || data[1] != 0x4D || data[2] != 0x3E) return;
  
  uint8_t payload_length = data[3];
  uint8_t command = data[4];
  uint8_t* payload = &data[5];
  
  String jsonOutput = "{";
  
  switch (command) {
    case 0x65: // MSP_STATUS
      if (payload_length >= 11) {
        uint16_t cycleTime = payload[0] | (payload[1] << 8);
        uint16_t i2cErrors = payload[2] | (payload[3] << 8);
        uint16_t sensors = payload[4] | (payload[5] << 8);
        uint32_t flightModes = payload[6] | (payload[7] << 8) | (payload[8] << 16) | (payload[9] << 24);
        uint8_t profile = payload[10];
        
        jsonOutput += "\"type\":\"status\",";
        jsonOutput += "\"cycleTime\":" + String(cycleTime) + ",";
        jsonOutput += "\"i2cErrors\":" + String(i2cErrors) + ",";
        jsonOutput += "\"sensors\":" + String(sensors) + ",";
        jsonOutput += "\"flightModes\":" + String(flightModes) + ",";
        jsonOutput += "\"profile\":" + String(profile);
      }
      break;
      
    case 0x6C: // MSP_ATTITUDE
      if (payload_length >= 6) {
        int16_t roll = payload[0] | (payload[1] << 8);
        int16_t pitch = payload[2] | (payload[3] << 8);
        int16_t yaw = payload[4] | (payload[5] << 8);
        
        // Convert to degrees (MSP sends in decidegrees)
        float rollDeg = roll / 10.0;
        float pitchDeg = pitch / 10.0;
        float yawDeg = yaw / 10.0;
        
        jsonOutput += "\"type\":\"attitude\",";
        jsonOutput += "\"roll\":" + String(rollDeg, 1) + ",";
        jsonOutput += "\"pitch\":" + String(pitchDeg, 1) + ",";
        jsonOutput += "\"yaw\":" + String(yawDeg, 1);
      }
      break;
      
    case 0x6D: // MSP_ALTITUDE
      if (payload_length >= 6) {
        int32_t altitude = payload[0] | (payload[1] << 8) | (payload[2] << 16) | (payload[3] << 24);
        int16_t vario = payload[4] | (payload[5] << 8);
        
        // Convert to meters
        float altitudeM = altitude / 100.0;
        float varioMS = vario / 100.0;
        
        jsonOutput += "\"type\":\"altitude\",";
        jsonOutput += "\"altitude\":" + String(altitudeM, 2) + ",";
        jsonOutput += "\"vario\":" + String(varioMS, 2);
      }
      break;
      
    case 0x6A: // MSP_RAW_GPS
      if (payload_length >= 16) {
        uint8_t fix = payload[0];
        uint8_t satellites = payload[1];
        int32_t lat = payload[2] | (payload[3] << 8) | (payload[4] << 16) | (payload[5] << 24);
        int32_t lon = payload[6] | (payload[7] << 8) | (payload[8] << 16) | (payload[9] << 24);
        uint16_t altitude = payload[10] | (payload[11] << 8);
        uint16_t speed = payload[12] | (payload[13] << 8);
        uint16_t ground_course = payload[14] | (payload[15] << 8);
        
        // Convert coordinates (divide by 10,000,000 for degrees)
        float latitude = lat / 10000000.0;
        float longitude = lon / 10000000.0;
        
        jsonOutput += "\"type\":\"gps\",";
        jsonOutput += "\"fix\":" + String(fix) + ",";
        jsonOutput += "\"satellites\":" + String(satellites) + ",";
        jsonOutput += "\"latitude\":" + String(latitude, 7) + ",";
        jsonOutput += "\"longitude\":" + String(longitude, 7) + ",";
        jsonOutput += "\"altitude\":" + String(altitude) + ",";
        jsonOutput += "\"speed\":" + String(speed) + ",";
        jsonOutput += "\"course\":" + String(ground_course);
      }
      break;
      
    case 0x66: // MSP_RAW_IMU
      if (payload_length >= 18) {
        int16_t accX = payload[0] | (payload[1] << 8);
        int16_t accY = payload[2] | (payload[3] << 8);
        int16_t accZ = payload[4] | (payload[5] << 8);
        int16_t gyroX = payload[6] | (payload[7] << 8);
        int16_t gyroY = payload[8] | (payload[9] << 8);
        int16_t gyroZ = payload[10] | (payload[11] << 8);
        int16_t magX = payload[12] | (payload[13] << 8);
        int16_t magY = payload[14] | (payload[15] << 8);
        int16_t magZ = payload[16] | (payload[17] << 8);
        
        jsonOutput += "\"type\":\"imu\",";
        jsonOutput += "\"acc\":[" + String(accX) + "," + String(accY) + "," + String(accZ) + "],";
        jsonOutput += "\"gyro\":[" + String(gyroX) + "," + String(gyroY) + "," + String(gyroZ) + "],";
        jsonOutput += "\"mag\":[" + String(magX) + "," + String(magY) + "," + String(magZ) + "]";
      }
      break;
      
    case 0x68: // MSP_MOTOR
      if (payload_length >= 8) { // Assuming 4 motors
        uint16_t motor1 = payload[0] | (payload[1] << 8);
        uint16_t motor2 = payload[2] | (payload[3] << 8);
        uint16_t motor3 = payload[4] | (payload[5] << 8);
        uint16_t motor4 = payload[6] | (payload[7] << 8);
        
        jsonOutput += "\"type\":\"motors\",";
        jsonOutput += "\"motors\":[" + String(motor1) + "," + String(motor2) + "," + String(motor3) + "," + String(motor4) + "]";
      }
      break;
      
    case 0x69: // MSP_RC
      if (payload_length >= 16) { // 8 channels minimum
        jsonOutput += "\"type\":\"rc\",";
        jsonOutput += "\"channels\":[";
        for (int i = 0; i < payload_length/2 && i < 8; i++) {
          uint16_t channel = payload[i*2] | (payload[i*2+1] << 8);
          jsonOutput += String(channel);
          if (i < (payload_length/2 - 1) && i < 7) jsonOutput += ",";
        }
        jsonOutput += "]";
      }
      break;
      
    default:
      return; // Unknown command, don't send
  }
  
  jsonOutput += ",\"timestamp\":" + String(millis()) + "}";
  
  // Send formatted JSON data to iPhone
  sendFormattedData(jsonOutput);
  
  // Increment packet counter for statistics
  packetsPerSecond++;
}

void setup() {
  // Start the standard Serial port for debugging
  Serial.begin(115200);
  Serial.println("\nConfiguring INAV Serial-to-UDP Bridge...");
  Serial.println("Using GPIO4 (RX) and GPIO2 (TX) for flight controller communication");

  // Start the serial port that connects to the flight controller
  // Using custom GPIO pins: RX=4, TX=2 (verified working in loopback test)
  FC_SERIAL.begin(FC_BAUD_RATE, SERIAL_8N1, 4, 2);
  Serial.println("Serial2 initialized with custom GPIO pins");
  Serial.println("ESP32 GPIO4 (RX2) -> FC T6, ESP32 GPIO2 (TX2) -> FC R6");
  Serial.print("Flight controller baud rate: ");
  Serial.println(FC_BAUD_RATE);
  
  // Start the ESP32 in Access Point mode
  WiFi.softAP(ssid, password);
  IPAddress myIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(myIP);

  // Begin listening for UDP packets
  udp.begin(udpPort);
  Serial.print("Listening for UDP packets on port ");
  Serial.println(udpPort);
  Serial.println("Waiting for first packet from client app...");
}

void loop() {
  // === Part 1: Forward UDP data (from iPhone) to the Flight Controller ===
  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    // If this is the first packet, store the client's IP and port
    if (!clientConnected) {
      clientIp = udp.remoteIP();
      clientPort = udp.remotePort();
      clientConnected = true;
      Serial.print("Client connected: ");
      Serial.println(clientIp);
    }
    
    // Read the packet and write it directly to the flight controller
    int len = udp.read(udp_buffer, 256);
    if (len > 0) {
      FC_SERIAL.write(udp_buffer, len);
      
      // Send UDP acknowledgment back to iPhone (optional)
      String ackMessage = "message received!";
      udp.beginPacket(clientIp, clientPort);
      udp.print(ackMessage);
      udp.endPacket();
      
      // Log iPhone commands (useful for debugging autonomous commands)
      Serial.print("iPhone→FC: ");
      Serial.print(len);
      Serial.println(" bytes");
    }
  }

  // === Part 2: Parse and Forward Flight Controller Data ===
  // Parse MSP packets and send formatted JSON to iPhone
  while (FC_SERIAL.available()) {
    uint8_t incomingByte = FC_SERIAL.read();
    
    // Look for MSP packet start: $M>
    if (msp_buffer_pos == 0 && incomingByte == 0x24) { // $
      msp_buffer[msp_buffer_pos++] = incomingByte;
    } else if (msp_buffer_pos == 1 && incomingByte == 0x4D) { // M
      msp_buffer[msp_buffer_pos++] = incomingByte;
    } else if (msp_buffer_pos == 2 && incomingByte == 0x3E) { // >
      msp_buffer[msp_buffer_pos++] = incomingByte;
    } else if (msp_buffer_pos >= 3) {
      msp_buffer[msp_buffer_pos++] = incomingByte;
      
      // Check if we have complete packet
      if (msp_buffer_pos >= 4) {
        uint8_t payload_length = msp_buffer[3];
        uint8_t expected_length = 6 + payload_length; // Header(3) + Length(1) + Command(1) + Payload + Checksum(1)
        
        if (msp_buffer_pos >= expected_length) {
          // Parse and send formatted data
          parseMSPPacket(msp_buffer, msp_buffer_pos);
          
          // Reset buffer for next packet
          msp_buffer_pos = 0;
        } else if (msp_buffer_pos >= 256) {
          // Buffer overflow protection
          msp_buffer_pos = 0;
        }
      }
    } else {
      // Reset if we don't get proper header sequence
      msp_buffer_pos = 0;
    }
  }
  
  // Keep data rate logging
  static unsigned long lastDataLog = 0;
  if (millis() - lastDataLog > 1000) {
    lastDataLog = millis();
    Serial.print("Parsed packets/sec: ");
    Serial.println(packetsPerSecond);
    packetsPerSecond = 0; // Reset counter
  }
  
  // Request continuous telemetry data from INAV flight controller
  static unsigned long lastTelemetryRequest = 0;
  
  if (millis() - lastTelemetryRequest > 100) { // Request telemetry every 100ms (10Hz)
    lastTelemetryRequest = millis();
    
    // Request multiple telemetry data types for comprehensive drone data
    
    // MSP_ATTITUDE - Roll, Pitch, Yaw angles
    uint8_t msp_attitude[] = {0x24, 0x4D, 0x3C, 0x00, 0x6C, 0x6C};
    FC_SERIAL.write(msp_attitude, sizeof(msp_attitude));
    
    delay(5);
    
    // MSP_ALTITUDE - Altitude and variometer
    uint8_t msp_altitude[] = {0x24, 0x4D, 0x3C, 0x00, 0x6D, 0x6D};
    FC_SERIAL.write(msp_altitude, sizeof(msp_altitude));
    
    delay(5);
    
    // MSP_RAW_GPS - GPS coordinates, speed, ground course
    uint8_t msp_raw_gps[] = {0x24, 0x4D, 0x3C, 0x00, 0x6A, 0x6A};
    FC_SERIAL.write(msp_raw_gps, sizeof(msp_raw_gps));
    
    delay(5);
    
    // MSP_RC - RC channel values
    uint8_t msp_rc[] = {0x24, 0x4D, 0x3C, 0x00, 0x69, 0x69};
    FC_SERIAL.write(msp_rc, sizeof(msp_rc));
    
    delay(5);
    
    // MSP_RAW_IMU - Accelerometer, Gyroscope, Magnetometer
    uint8_t msp_raw_imu[] = {0x24, 0x4D, 0x3C, 0x00, 0x66, 0x66};
    FC_SERIAL.write(msp_raw_imu, sizeof(msp_raw_imu));
    
    delay(5);
    
    // MSP_MOTOR - Motor values
    uint8_t msp_motor[] = {0x24, 0x4D, 0x3C, 0x00, 0x68, 0x68};
    FC_SERIAL.write(msp_motor, sizeof(msp_motor));
    
    delay(5);
    
    // MSP_STATUS - Flight mode, armed state, battery
    uint8_t msp_status[] = {0x24, 0x4D, 0x3C, 0x00, 0x65, 0x65};
    FC_SERIAL.write(msp_status, sizeof(msp_status));
  }
  
  // Periodic status message (less frequent)
  static unsigned long lastStatusMsg = 0;
  if (millis() - lastStatusMsg > 10000) { // Every 10 seconds
    lastStatusMsg = millis();
    Serial.println("Bridge active - streaming telemetry to iPhone");
    if (clientConnected) {
      Serial.println("iPhone connected - full duplex communication active");
    } else {
      Serial.println("Waiting for iPhone connection...");
    }
  }

  delay(2);
}