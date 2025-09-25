#include <WiFi.h>
#include <WiFiUdp.h>
#include <string.h>

// --- Wi-Fi Settings ---
const char *ssid = "INAV_Bridge_Network";
const char *password = "drone12345";

// --- UDP Settings ---
unsigned int udpPort = 14550; // The port your iPhone app will send to and listen on

// --- Serial Bridge Settings ---
// We'll use Serial2 for the flight controller connection.
// Default pins for Serial2 are GPIO 16 (RX) and GPIO 17 (TX).
#define FC_SERIAL Serial2
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
  Serial.println("\nConfiguring INAV Serial-to-UDP Bridge...");

  // Start the serial port that connects to the flight controller
  FC_SERIAL.begin(FC_BAUD_RATE);
  
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
    }
  }

  // === Part 2: Forward Serial data (from Flight Controller) to the iPhone ===
  // Only forward data if a client has connected
  if (clientConnected) {
    int bytesAvailable = FC_SERIAL.available();
    if (bytesAvailable > 0) {
      // Read the bytes from the flight controller
      int bytesRead = FC_SERIAL.read(serial_buffer, 256);

      // --- START: Add this code for debugging ---
  Serial.print("Sending ");
  Serial.print(bytesRead);
  Serial.println(" bytes from FC:");

  for (int i = 0; i < bytesRead; i++) {
    if (serial_buffer[i] < 0x10) {
      Serial.print("0"); // Add a leading zero for single-digit hex values
    }
    Serial.print(serial_buffer[i], HEX);
    Serial.print(" ");
  }
  Serial.println(); // Print a newline to separate messages
  // --- END: Debugging code ---

  // Send the bytes via UDP to the iPhone
  udp.beginPacket(clientIp, clientPort);
  udp.write(serial_buffer, bytesRead);
  udp.endPacket();
    }
  }

  delay(2);
}