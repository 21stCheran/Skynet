# Skynet Drone Control Center

A professional web-based control interface for the Skynet drone system. This React application provides a comprehensive testing and control interface for ESP32-powered drones running the INAV bridge firmware.

## Features

### 🎛️ **Professional Control Interface**

- **Connection Management**: Easy ESP32 IP/port configuration with status indicators
- **Flight Controls**: Intuitive hover, movement, and emergency controls
- **Real-time Telemetry**: Live message logging and communication monitoring
- **Safety Features**: Emergency stop, arming controls, and visual status indicators

### 🚁 **Drone Command Support**

- **Basic Controls**: Arm, disarm, emergency stop
- **Hover Commands**: Preset altitudes (30cm, 50cm, 100cm, 150cm) with custom altitude slider
- **Movement Controls**: Forward, backward, left, right with adjustable intensity
- **Test Sequences**: Motor testing with safety warnings

### 🎨 **Modern UI/UX**

- **Dark Theme**: Professional aerospace-inspired design
- **Material-UI Components**: Polished, responsive interface
- **Real-time Status**: Connection status, armed state, and command feedback
- **Export Functionality**: Save telemetry logs for analysis

## Quick Start

### Prerequisites

- Node.js 20.19+ (current: 20.18.0 with warnings)
- ESP32 running Skynet BetaFlightControl firmware
- Drone connected to ESP32 WiFi network

### Installation

1. **Install Dependencies**

```bash
cd "C:\Users\arich\Documents\Skynet Drone\WebApp\SkynetTel"
npm install
```

2. **Start Everything (One Command!)**

```bash
npm run dev
```

This automatically starts:

- 🌉 **WebSocket-UDP Bridge** on port 14551
- ⚛️ **React Dev Server** on port 5174

3. **Open Browser**
   Navigate to `http://localhost:5174`

### Usage

1. **Connect to ESP32**

   - Default IP: `192.168.4.1`
   - Default Port: `14550`
   - Click "Connect" button

2. **Safety First**

   - Always remove propellers for testing
   - Use emergency stop if needed
   - Monitor connection status

3. **Test Commands**
   - Start with motor test (no props)
   - Test arming/disarming
   - Try hover commands at low altitudes
   - Test movement with low intensity

## Architecture

### Communication Flow

```
React App -> WebSocket/HTTP -> ESP32 -> MSP/RC -> INAV Flight Controller
```

### Key Components

- **`useESP32Connection`**: WebSocket/UDP communication hook
- **`ConnectionPanel`**: ESP32 connection management
- **`FlightControlPanel`**: Main control interface
- **`TelemetryPanel`**: Message logging and monitoring

### Command Format

All commands use JSON format matching ESP32 firmware:

```json
{
  "command": "hover",
  "value": 50
}
```

## Supported Commands

| Command    | Value  | Description                 |
| ---------- | ------ | --------------------------- |
| `arm`      | 1      | Arm the drone               |
| `disarm`   | 0      | Disarm the drone            |
| `stop`     | 0      | Emergency stop              |
| `hover`    | 10-300 | Hover at altitude (cm)      |
| `forward`  | 10-100 | Move forward (intensity %)  |
| `backward` | 10-100 | Move backward (intensity %) |
| `left`     | 10-100 | Move left (intensity %)     |
| `right`    | 10-100 | Move right (intensity %)    |
| `test`     | -      | Motor test sequence         |

## Safety Features

### Built-in Protections

- ⚠️ **Visual Safety Warnings**: Prominent safety alerts and prop removal reminders
- 🔴 **Emergency Stop**: Large, accessible emergency stop button
- 🛡️ **Connection Monitoring**: Real-time connection status with auto-reconnect
- 📊 **Command Validation**: Input validation and range checking
- 📝 **Activity Logging**: Complete command and response logging

### Testing Protocol

1. **Remove propellers** before any testing
2. **Start with motor test** to verify basic functionality
3. **Test arming/disarming** cycle
4. **Use low hover altitudes** (30-50cm) initially
5. **Start with gentle movements** (20-30% intensity)

## Development

### Build for Production

```bash
npm run build
```

### Linting

```bash
npm run lint
```

### Project Structure

```
src/
├── components/          # React components
│   ├── ConnectionPanel.jsx
│   ├── FlightControlPanel.jsx
│   └── TelemetryPanel.jsx
├── hooks/              # Custom React hooks
│   └── useESP32Connection.js
├── utils/              # Utility functions
│   └── flightCommands.js
├── App.jsx             # Main application
└── main.jsx            # Entry point
```

## Integration with ESP32

This web interface is designed to work with the `BetaFlightControl.ino` firmware:

### ESP32 Requirements

- WiFi AP mode: `INAV_Bridge_Network`
- UDP port: `14550`
- JSON command parsing
- MSP bridge to INAV

### Communication Protocol

- **UDP Messages**: JSON commands sent to ESP32
- **Response Handling**: JSON responses from ESP32
- **Telemetry Forward**: Raw MSP data forwarded from INAV

## Troubleshooting

### Connection Issues

- Verify ESP32 WiFi network is active
- Check IP address (default: 192.168.4.1)
- Ensure firewall allows UDP traffic
- Try browser developer tools for WebSocket errors

### Command Issues

- Check command format in telemetry log
- Verify ESP32 serial monitor for received commands
- Ensure drone is properly armed before movement
- Check INAV configuration for proper MSP setup

## Future Enhancements

### Planned Features

- 📡 **Real-time Telemetry Display**: Altitude, attitude, GPS data
- 🗺️ **GPS Waypoint Planning**: Mission planning interface
- 📹 **Camera Controls**: iPhone camera integration
- 🤖 **Autonomous Modes**: Pre-programmed flight patterns
- 📊 **Flight Data Recording**: Comprehensive logging and analysis

### Technical Improvements

- WebRTC for lower latency communication
- PWA support for mobile installation
- Advanced PID tuning interface
- Multi-drone support

## License

Part of the Skynet Drone project. See main project repository for licensing information.

## Contributing

This is part of the larger Skynet drone project. For development setup and contribution guidelines, see the main project documentation.

---

**⚠️ SAFETY REMINDER**: Always follow proper safety protocols when testing drone systems. Remove propellers during initial testing and ensure adequate safety measures are in place.+ Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## React Compiler

The React Compiler is not enabled on this template. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and [`typescript-eslint`](https://typescript-eslint.io) in your project.
