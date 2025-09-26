#include <Arduino.h>

#define MSP_SET_RAW_RC 200
HardwareSerial fcSerial(2);

// Correct AETR Mapping:
// rcChannels[0] = Roll
// rcChannels[1] = Pitch
// rcChannels[2] = Throttle  <-- CORRECTED
// rcChannels[3] = Yaw      <-- CORRECTED
// rcChannels[4] = AUX1 (Arm)
uint16_t rcChannels[8];

unsigned long lastMspSendTime = 0;
unsigned long testStartTime = 0;
const long mspUpdateInterval = 20;

enum TestState { IDLE, ARMING, FULL_THROTTLE, DISARMING };
TestState currentState = IDLE;

void sendMspCommand(uint8_t command, uint16_t *payload, uint8_t payloadSize) {
  fcSerial.write('$'); fcSerial.write('M'); fcSerial.write('<');
  fcSerial.write(payloadSize); fcSerial.write(command);
  uint8_t checksum = 0;
  checksum ^= payloadSize; checksum ^= command;
  for (int i = 0; i < payloadSize; i++) {
    uint8_t b = ((uint8_t *)payload)[i];
    fcSerial.write(b);
    checksum ^= b;
  }
  fcSerial.write(checksum);
}

void setup() {
  Serial.begin(115200);
  Serial.println("Final MSP Controller Initializing (AETR Corrected)...");
  fcSerial.begin(115200, SERIAL_8N1, 25, 26);

  // Initialize channels with correct AETR map
  rcChannels[0] = 1500; // Roll center
  rcChannels[1] = 1500; // Pitch center
  rcChannels[2] = 1000; // Throttle low  <-- CORRECTED
  rcChannels[3] = 1500; // Yaw center    <-- CORRECTED
  rcChannels[4] = 1000; // AUX1 (Arm switch) low
  rcChannels[5] = 1000; // AUX2 low
  rcChannels[6] = 1000; // AUX3 low
  rcChannels[7] = 1000; // AUX4 low
  testStartTime = millis();
}

void loop() {
  if (millis() - lastMspSendTime > mspUpdateInterval) {
    sendMspCommand(MSP_SET_RAW_RC, rcChannels, 16);
    lastMspSendTime = millis();
  }

  switch (currentState) {
    case IDLE:
      if (millis() - testStartTime > 5000) {
        Serial.println("ARMING...");
        rcChannels[4] = 2000; // Set AUX1 high to arm
        currentState = ARMING;
        testStartTime = millis();
      }
      break;
    case ARMING:
      if (millis() - testStartTime > 500) {
        Serial.println("FULL THROTTLE...");
        rcChannels[2] = 2000; // Set THROTTLE to max <-- CORRECTED
        currentState = FULL_THROTTLE;
        testStartTime = millis();
      }
      break;
    case FULL_THROTTLE:
      if (millis() - testStartTime > 5000) {
        Serial.println("DISARMING...");
        rcChannels[2] = 1000; // Set THROTTLE to low <-- CORRECTED
        rcChannels[4] = 1000; // Set AUX1 low to disarm
        currentState = DISARMING;
      }
      break;
    case DISARMING:
      break;
  }
}