#include <Arduino.h>

// We are using UART port 2 (there are 3 on the ESP32: 0, 1, 2)
// We will assign it to custom pins instead of using the default.
HardwareSerial mySerial(2);

void setup() {
  // Serial for the computer monitor
  Serial.begin(115200);

  // Start our custom serial port.
  // Format: begin(baud, config, RX_PIN, TX_PIN);
  // We will use GPIO 25 for RX and GPIO 26 for TX.
  mySerial.begin(115200, SERIAL_8N1, 25, 26);
  
  Serial.println("Starting NEW Loopback Test on GPIO 25 & 26...");
}

void loop() {
  // Send a message out of our custom TX pin (GPIO 26)
  mySerial.println("Hello from custom pins!");
  
  delay(1000);

  // Check if any data came back into our custom RX pin (GPIO 25)
  if (mySerial.available()) {
    String message = mySerial.readString();
    Serial.print("Loopback Success! Received: ");
    Serial.print(message);
  } else {
    Serial.println("Loopback FAILED. Still no data received.");
  }
}