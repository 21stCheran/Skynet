import React from "react";
import {
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Box,
  Chip,
  Alert,
  Grid,
} from "@mui/material";
import { Wifi, WifiOff, Settings, Router } from "@mui/icons-material";

const ConnectionPanel = ({
  isConnected,
  connectionStatus,
  esp32IP,
  setESP32IP,
  esp32Port,
  setESP32Port,
  onConnect,
  onDisconnect,
}) => {
  const handleConnect = () => {
    if (isConnected) {
      onDisconnect();
    } else {
      onConnect();
    }
  };

  const getStatusColor = () => {
    if (isConnected) return "success";
    if (
      connectionStatus.includes("Error") ||
      connectionStatus.includes("Failed")
    )
      return "error";
    if (connectionStatus.includes("Connecting")) return "warning";
    return "default";
  };

  return (
    <Card elevation={3}>
      <CardContent>
        <Box display="flex" alignItems="center" gap={2} mb={2}>
          <Router color="action" />
          <Typography variant="h6" component="h2">
            ESP32 Connection
          </Typography>
          <Chip
            icon={isConnected ? <Wifi /> : <WifiOff />}
            label={connectionStatus}
            color={getStatusColor()}
            variant={isConnected ? "filled" : "outlined"}
          />
        </Box>

        {!isConnected && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Enter the IP address and port of your ESP32 drone controller.
            Default values match the ESP32 firmware configuration.
          </Alert>
        )}

        <Grid container spacing={2} alignItems="center">
          <Grid item xs={12} sm={4}>
            <TextField
              fullWidth
              label="ESP32 IP Address"
              value={esp32IP}
              onChange={(e) => setESP32IP(e.target.value)}
              disabled={isConnected}
              placeholder="192.168.4.1"
              helperText="Default: 192.168.4.1"
              variant="outlined"
              size="small"
            />
          </Grid>

          <Grid item xs={12} sm={3}>
            <TextField
              fullWidth
              label="Port"
              value={esp32Port}
              onChange={(e) => setESP32Port(e.target.value)}
              disabled={isConnected}
              placeholder="14550"
              helperText="Default: 14550"
              variant="outlined"
              size="small"
              type="number"
            />
          </Grid>

          <Grid item xs={12} sm={3}>
            <Button
              fullWidth
              variant="contained"
              color={isConnected ? "error" : "primary"}
              onClick={handleConnect}
              startIcon={isConnected ? <WifiOff /> : <Wifi />}
              size="large"
            >
              {isConnected ? "Disconnect" : "Connect"}
            </Button>
          </Grid>

          <Grid item xs={12} sm={2}>
            <Button
              fullWidth
              variant="outlined"
              startIcon={<Settings />}
              disabled={!isConnected}
              size="large"
            >
              Settings
            </Button>
          </Grid>
        </Grid>

        {isConnected && (
          <Box mt={2}>
            <Alert severity="success">
              <Typography variant="body2">
                <strong>Connected to:</strong> {esp32IP}:{esp32Port}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Ready to send flight commands to your Skynet drone.
              </Typography>
            </Alert>
          </Box>
        )}
      </CardContent>
    </Card>
  );
};

export default ConnectionPanel;
