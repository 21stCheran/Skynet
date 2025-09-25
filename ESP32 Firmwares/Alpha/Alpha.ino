#include <WiFi.h>
#include <WiFiUdp.h>
#include <string.h> // Required for strcmp() and strlen()

// --- Wi-Fi Settings ---
// You can change these to your desired network name and password
const char *ssid = "ESP32_Test_Network";
const char *password = "drone12345";

// --- UDP Settings ---
// MAVLink ground stations typically listen on port 14550
unsigned int udpPort = 14550;
IPAddress broadcastIp(192, 168, 4, 255); // Broadcast IP for AP mode

// Create a UDP object
WiFiUDP udp;

// Buffer to hold incoming packets
char packetBuffer[256];

void setup() {
  // Start the Serial Monitor to see debug messages
  Serial.begin(115200);
  Serial.println();
  Serial.println("Configuring access point...");

  // Start the ESP32 in Access Point mode
  WiFi.softAP(ssid, password);

  // Print the IP address of the Access Point
  IPAddress myIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(myIP);

  // Begin listening for UDP packets on the specified port
  udp.begin(udpPort);
  Serial.print("Listening for UDP packets on port ");
  Serial.println(udpPort);
}

void loop() {
  // 1. Check for and process any incoming UDP packets
  int packetSize = udp.parsePacket();
  if (packetSize) {
    Serial.print("Received packet of size ");
    Serial.println(packetSize);

    // Store the sender's IP and port before reading the packet
    IPAddress remoteIp = udp.remoteIP();
    int remotePort = udp.remotePort();

    // Read the packet into the buffer
    int len = udp.read(packetBuffer, 255);
    if (len > 0) {
      packetBuffer[len] = '\0'; // Null-terminate the string
    }

    Serial.print("From ");
    Serial.print(remoteIp);
    Serial.print(":");
    Serial.println(remotePort);

    Serial.print("Contents: ");
    Serial.println(packetBuffer);

    // Check if the received message is the specific command "nigatoni"
    if (strcmp(packetBuffer, "nigatoni") == 0) {
      Serial.println("Command 'nigatoni' received. Sending reply...");
      
      // Send the response "nigatoni" back to the original sender
      udp.beginPacket(remoteIp, remotePort);
      // ==================== CORRECTED LINE 1 ====================
      udp.write((const uint8_t*)"nigatoni", strlen("nigatoni"));
      // ==========================================================
      udp.endPacket();

      Serial.println("Reply sent.");
    }
  }

  // 2. Send a broadcast UDP packet every 2 seconds
  delay(2000);

  udp.beginPacket(broadcastIp, udpPort);
  // ==================== CORRECTED LINE 2 ====================
  udp.write((const uint8_t*)"Hello from ESP32!", strlen("Hello from ESP32!"));
  // ==========================================================
  udp.endPacket();

  Serial.println("Broadcast packet sent.");
}