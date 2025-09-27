/**
 * WebSocket to UDP Bridge Server
 * Allows the web interface to communicate with ESP32 via UDP
 *
 * Usage:
 * 1. Start this server: node websocket-udp-bridge.js
 * 2. Web interface connects to WebSocket port (14551)
 * 3. Server forwards messages to ESP32 UDP port (14550)
 */

import { WebSocketServer } from "ws";
import dgram from "dgram";
import process from "process";

// Configuration
const WS_PORT = 14551; // WebSocket port for web interface
const ESP32_IP = "192.168.4.1"; // ESP32 IP address
const ESP32_PORT = 14550; // ESP32 UDP port

// Create WebSocket server
const wss = new WebSocketServer({ port: WS_PORT });

// Create UDP client
const udpClient = dgram.createSocket("udp4");

console.log(`🚀 Skynet WebSocket-UDP Bridge starting...`);
console.log(`📡 WebSocket Server: ws://localhost:${WS_PORT}`);
console.log(`🎯 ESP32 Target: ${ESP32_IP}:${ESP32_PORT}`);
console.log(`🚁 Ready for drone commands!`);

// Handle WebSocket connections
wss.on("connection", (ws, req) => {
  const clientIP = req.socket.remoteAddress;
  console.log(`🔗 Web client connected from ${clientIP}`);

  // Send welcome message
  ws.send(
    JSON.stringify({
      type: "system",
      message: "Connected to WebSocket-UDP bridge",
      timestamp: new Date().toISOString(),
    })
  );

  // Handle messages from web client
  ws.on("message", (data) => {
    try {
      const message = data.toString();
      console.log(`📤 Web->ESP32: ${message}`);

      // Forward message to ESP32 via UDP
      udpClient.send(message, ESP32_PORT, ESP32_IP, (err) => {
        if (err) {
          console.error(`❌ UDP send error: ${err.message}`);
          ws.send(
            JSON.stringify({
              type: "error",
              message: `Failed to send to ESP32: ${err.message}`,
              timestamp: new Date().toISOString(),
            })
          );
        } else {
          console.log(`✅ Message forwarded to ESP32`);
        }
      });
    } catch (error) {
      console.error(`❌ Message processing error: ${error.message}`);
      ws.send(
        JSON.stringify({
          type: "error",
          message: `Message processing error: ${error.message}`,
          timestamp: new Date().toISOString(),
        })
      );
    }
  });

  // Handle WebSocket close
  ws.on("close", () => {
    console.log(`🔌 Web client disconnected`);
  });

  // Handle WebSocket errors
  ws.on("error", (error) => {
    console.error(`❌ WebSocket error: ${error.message}`);
  });
});

// Handle UDP responses from ESP32
udpClient.on("message", (message, remote) => {
  const messageStr = message.toString();
  console.log(
    `📥 ESP32->Web: ${messageStr} from ${remote.address}:${remote.port}`
  );

  // Forward response to all connected web clients
  wss.clients.forEach((client) => {
    if (client.readyState === client.OPEN) {
      client.send(
        JSON.stringify({
          type: "response",
          message: messageStr,
          timestamp: new Date().toISOString(),
          source: `${remote.address}:${remote.port}`,
        })
      );
    }
  });
});

// Handle UDP errors
udpClient.on("error", (error) => {
  console.error(`❌ UDP error: ${error.message}`);

  // Notify web clients of UDP errors
  wss.clients.forEach((client) => {
    if (client.readyState === client.OPEN) {
      client.send(
        JSON.stringify({
          type: "error",
          message: `UDP error: ${error.message}`,
          timestamp: new Date().toISOString(),
        })
      );
    }
  });
});

// Bind UDP client
udpClient.bind(() => {
  console.log(`📡 UDP client bound and ready`);
});

// Handle server shutdown
process.on("SIGINT", () => {
  console.log(`\n🛑 Shutting down WebSocket-UDP bridge...`);

  // Close WebSocket server
  wss.close(() => {
    console.log(`🔌 WebSocket server closed`);
  });

  // Close UDP client
  udpClient.close(() => {
    console.log(`📡 UDP client closed`);
    process.exit(0);
  });
});

console.log(`✅ WebSocket-UDP Bridge Server running!`);
console.log(`\nUsage:`);
console.log(`1. Connect your web interface to: ws://localhost:${WS_PORT}`);
console.log(`2. Ensure ESP32 is running on: ${ESP32_IP}:${ESP32_PORT}`);
console.log(`3. Send JSON commands through the web interface`);
console.log(`\nPress Ctrl+C to stop the server`);
