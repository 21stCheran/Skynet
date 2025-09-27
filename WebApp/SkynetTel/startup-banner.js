#!/usr/bin/env node
/**
 * Skynet Drone Control System Startup Banner
 * Shows system information and status
 */
import process from "process";

console.log(`
╔══════════════════════════════════════════════════════════════╗
║                   🚁 SKYNET DRONE CONTROL                   ║
║                      System Starting...                     ║
╚══════════════════════════════════════════════════════════════╝

🔧 System Information:
   • Node.js Version: ${process.version}
   • Platform: ${process.platform}
   • Architecture: ${process.arch}

🌐 Services Starting:
   • WebSocket-UDP Bridge: ws://localhost:14551
   • React Dev Server: http://localhost:5174
   • ESP32 Target: 192.168.4.1:14550

⚠️  Safety Reminders:
   • Remove propellers before testing
   • Keep emergency stop accessible
   • Monitor connection status
   • Follow local drone regulations

🚀 Ready for drone control operations!
`);

// Export for potential programmatic use
export const systemInfo = {
  nodeVersion: process.version,
  platform: process.platform,
  arch: process.arch,
  services: {
    bridge: "ws://localhost:14551",
    react: "http://localhost:5174",
    esp32: "192.168.4.1:14550",
  },
};
