#include <HardwareSerial.h>

// Simple ESP32 Serial2 Loopback Test
// This test will verify that Serial2 (GPIO16 RX, GPIO17 TX) is working correctly
// Instructions: Connect GPIO17 to GPIO16 with a jumper wire before uploading

#define TEST_SERIAL Serial2

void setup() {
  // Start the debug serial port
  Serial.begin(115200);
  Serial.println("\n=== ESP32 Serial2 Loopback Test ===");
  Serial.println("INSTRUCTIONS:");
  Serial.println("1. Connect GPIO2 (TX) to GPIO4 (RX) with a jumper wire");
  Serial.println("2. Upload this code");
  Serial.println("3. Watch for loopback data in serial monitor");
  Serial.println("=======================================\n");
  
  // Start Serial2 at 115200 baud
  TEST_SERIAL.begin(115200);
  
  delay(1000);
  Serial.println("Starting loopback test...");
}

void loop() {
  static unsigned long lastTest = 0;
  static int testCounter = 0;
  
  // Send test data every 2 seconds
  if (millis() - lastTest > 2000) {
    lastTest = millis();
    testCounter++;
    
    // Send test pattern
    uint8_t testData[] = {0xAA, 0xBB, 0xCC, 0xDD, (uint8_t)(testCounter & 0xFF)};
    
    Serial.print("Test #");
    Serial.print(testCounter);
    Serial.print(" - Sending: ");
    for (int i = 0; i < sizeof(testData); i++) {
      if (testData[i] < 0x10) Serial.print("0");
      Serial.print(testData[i], HEX);
      Serial.print(" ");
    }
    Serial.println();
    
    // Send the data
    TEST_SERIAL.write(testData, sizeof(testData));
  }
  
  // Check for received data
  if (TEST_SERIAL.available()) {
    Serial.print("RECEIVED: ");
    while (TEST_SERIAL.available()) {
      uint8_t receivedByte = TEST_SERIAL.read();
      if (receivedByte < 0x10) Serial.print("0");
      Serial.print(receivedByte, HEX);
      Serial.print(" ");
    }
    Serial.println(" ✓ SUCCESS - ESP32 Serial2 is working!");
    Serial.println();
  }
  
  delay(10);
}