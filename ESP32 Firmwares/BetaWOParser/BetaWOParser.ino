#include <WiFi.h>
#include <WiFiUdp.h>
#include <string.h>

// --- Wi-Fi Settings ---
const char *ssid = "INAV_Bridge_Network";
const char *password = "drone12345";

// --- UDP Settings ---
unsigned int udpPort = 14550; // The port your iPhone app will send to and listen on

// --- Serial Bridge Settings ---
// Using GPIO4 (RX) and GPIO2 (TX) - verified working pins
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

void setup() {
  // Start the standard Serial port for debugging
  Serial.begin(115200);
  Serial.println("\nConfiguring INAV Serial-to-UDP Bridge (Raw Data)...");
  Serial.println("Using GPIO4 (RX) and GPIO2 (TX) for flight controller communication");

  // Start the serial port that connects to the flight controller
  // Using custom GPIO pins: RX=4, TX=2 (verified working in loopback test)
  FC_SERIAL.begin(FC_BAUD_RATE, SERIAL_8N1, 4, 2);
  Serial.println("Serial2 initialized with custom GPIO pins");
  Serial.println("ESP32 GPIO4 (RX2) -> FC T6, ESP32 GPIO2 (TX2) -> FC R6");
  
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
      Serial.print("iPhone→FC: ");
      Serial.print(len);
      Serial.println(" bytes");
    }
  }

  // === Part 2: Forward RAW Serial data (from Flight Controller) to the iPhone ===
  // Stream all flight controller data as-is to iPhone
  int bytesAvailable = FC_SERIAL.available();
  if (bytesAvailable > 0) {
    // Read the bytes from the flight controller
    int bytesRead = FC_SERIAL.read(serial_buffer, 256);

    // Forward raw data to iPhone if connected
    if (clientConnected && bytesRead > 0) {
      // Send the raw bytes via UDP to the iPhone immediately
      udp.beginPacket(clientIp, clientPort);
      udp.write(serial_buffer, bytesRead);
      udp.endPacket();
    }
  }
  
  // Request essential telemetry data only (minimal set)
  static unsigned long lastTelemetryRequest = 0;
  
  if (millis() - lastTelemetryRequest > 200) { // Request telemetry every 200ms (5Hz)
    lastTelemetryRequest = millis();
    
    // Only request the most essential data
    
    // MSP_ATTITUDE - Roll, Pitch, Yaw angles (most important for flight)
    uint8_t msp_attitude[] = {0x24, 0x4D, 0x3C, 0x00, 0x6C, 0x6C};
    FC_SERIAL.write(msp_attitude, sizeof(msp_attitude));
    
    delay(20);
    
    // MSP_STATUS - Flight mode, armed state, battery
    uint8_t msp_status[] = {0x24, 0x4D, 0x3C, 0x00, 0x65, 0x65};
    FC_SERIAL.write(msp_status, sizeof(msp_status));
    
    delay(20);
    
    // MSP_RAW_GPS - GPS coordinates (if available)
    uint8_t msp_raw_gps[] = {0x24, 0x4D, 0x3C, 0x00, 0x6A, 0x6A};
    FC_SERIAL.write(msp_raw_gps, sizeof(msp_raw_gps));
  }
  
  // Minimal status logging
  static unsigned long lastStatusMsg = 0;
  if (millis() - lastStatusMsg > 5000) { // Every 5 seconds
    lastStatusMsg = millis();
    if (clientConnected) {
      Serial.println("Bridge active - streaming raw MSP data to iPhone");
    } else {
      Serial.println("Waiting for iPhone connection...");
    }
  }

  delay(2);
}