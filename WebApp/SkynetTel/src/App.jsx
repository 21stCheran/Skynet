import React, { useState } from "react";
import {
  ThemeProvider,
  createTheme,
  CssBaseline,
  Container,
  Grid,
  Box,
  Typography,
  AppBar,
  Toolbar,
  Chip,
  Alert,
} from "@mui/material";
import { FlightTakeoff, Memory, NetworkWifi } from "@mui/icons-material";

import { useESP32Connection } from "./hooks/useESP32Connection";
import ConnectionPanel from "./components/ConnectionPanel";
import FlightControlPanel from "./components/FlightControlPanel";
import TelemetryPanel from "./components/TelemetryPanel";

// Create a professional dark theme for the drone interface
const theme = createTheme({
  palette: {
    mode: "dark",
    primary: {
      main: "#1976d2",
    },
    secondary: {
      main: "#dc004e",
    },
    background: {
      default: "#0a0a0a",
      paper: "#1a1a1a",
    },
    error: {
      main: "#f44336",
    },
    warning: {
      main: "#ff9800",
    },
    success: {
      main: "#4caf50",
    },
  },
  components: {
    MuiCard: {
      styleOverrides: {
        root: {
          backgroundImage: "linear-gradient(145deg, #1a1a1a 0%, #2a2a2a 100%)",
          border: "1px solid rgba(255, 255, 255, 0.1)",
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: "none",
          fontWeight: 600,
        },
      },
    },
  },
});

function App() {
  const {
    isConnected,
    connectionStatus,
    receivedMessages,
    esp32IP,
    setESP32IP,
    esp32Port,
    setESP32Port,
    connect,
    disconnect,
    sendMessage,
    clearMessages,
  } = useESP32Connection();

  const [isArmed, setIsArmed] = useState(false);

  const handleSendCommand = (command) => {
    const success = sendMessage(command);
    if (!success) {
      console.error("Failed to send command:", command);
    }
  };

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />

      {/* App Bar */}
      <AppBar
        position="static"
        elevation={0}
        sx={{
          bgcolor: "background.paper",
          borderBottom: "1px solid rgba(255,255,255,0.1)",
        }}
      >
        <Toolbar>
          <FlightTakeoff sx={{ mr: 2, color: "primary.main" }} />
          <Typography
            variant="h5"
            component="h1"
            sx={{ flexGrow: 1, fontWeight: 700 }}
          >
            Skynet Drone Control Center
          </Typography>
          <Box display="flex" gap={2} alignItems="center">
            <Chip
              icon={<NetworkWifi />}
              label={isConnected ? "Connected" : "Offline"}
              color={isConnected ? "success" : "error"}
              variant="outlined"
            />
            <Chip
              icon={<Memory />}
              label={isArmed ? "ARMED" : "SAFE"}
              color={isArmed ? "error" : "success"}
              variant="filled"
            />
          </Box>
        </Toolbar>
      </AppBar>

      <Container maxWidth="xl" sx={{ py: 3 }}>
        {/* Safety Warning */}
        <Alert severity="warning" sx={{ mb: 3 }}>
          <Typography variant="body1" fontWeight="bold">
            ⚠️ SAFETY NOTICE: This is a test interface for drone development
          </Typography>
          <Typography variant="body2">
            Always remove propellers when testing. Ensure adequate safety
            measures and follow local drone regulations. Never fly indoors or
            near people without proper safety protocols.
          </Typography>
        </Alert>

        <Grid container spacing={3}>
          {/* Left Column - Connection and Controls */}
          <Grid item xs={12} lg={8}>
            <Box display="flex" flexDirection="column" gap={3}>
              {/* Connection Panel */}
              <ConnectionPanel
                isConnected={isConnected}
                connectionStatus={connectionStatus}
                esp32IP={esp32IP}
                setESP32IP={setESP32IP}
                esp32Port={esp32Port}
                setESP32Port={setESP32Port}
                onConnect={connect}
                onDisconnect={disconnect}
              />

              {/* Flight Control Panel */}
              <FlightControlPanel
                isConnected={isConnected}
                onSendCommand={handleSendCommand}
                isArmed={isArmed}
                setIsArmed={setIsArmed}
              />
            </Box>
          </Grid>

          {/* Right Column - Telemetry */}
          <Grid item xs={12} lg={4}>
            <TelemetryPanel
              receivedMessages={receivedMessages}
              onClearMessages={clearMessages}
            />
          </Grid>
        </Grid>

        {/* Footer */}
        <Box mt={4} pt={3} borderTop="1px solid rgba(255,255,255,0.1)">
          <Typography variant="body2" color="text.secondary" align="center">
            Skynet Drone Control Interface • Built with React & Material-UI
            <br />
            Compatible with ESP32 firmware running INAV bridge protocol
          </Typography>
        </Box>
      </Container>
    </ThemeProvider>
  );
}

export default App;
