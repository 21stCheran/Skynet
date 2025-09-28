import React, { useState } from "react";
import {
  Card,
  CardContent,
  Typography,
  Button,
  Box,
  Grid,
  Alert,
  Slider,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Divider,
  Paper,
  Switch,
  FormControlLabel,
} from "@mui/material";
import {
  FlightTakeoff,
  FlightLand,
  Emergency,
  KeyboardArrowUp,
  KeyboardArrowDown,
  KeyboardArrowLeft,
  KeyboardArrowRight,
  Height,
  Speed,
  Build,
} from "@mui/icons-material";
import {
  FlightCommands,
  HOVER_PRESETS,
  MOVEMENT_INTENSITIES,
} from "../utils/flightCommands";

const FlightControlPanel = ({
  isConnected,
  onSendCommand,
  isArmed,
  setIsArmed,
}) => {
  const [customAltitude, setCustomAltitude] = useState(50);
  const [movementIntensity, setMovementIntensity] = useState(30);
  const [lastCommandSent, setLastCommandSent] = useState("");
  const [safeMode, setSafeMode] = useState(true); // NEW: Safe mode state
  const [currentThrottlePercentage, setCurrentThrottlePercentage] = useState(0); // NEW: Throttle percentage state

  const sendCommand = (commandFunction, description) => {
    if (!isConnected) return;

    const command = commandFunction(safeMode); // Pass safe mode to command function
    onSendCommand(command);
    setLastCommandSent(description + (safeMode ? " (Safe)" : " (Unsafe)"));
  };

  const handleArm = () => {
    sendCommand(FlightCommands.arm, "ARM");
    setIsArmed(true);
  };

  const handleDisarm = () => {
    if (safeMode) {
      sendCommand(FlightCommands.safeDisarm, "SAFE DISARM");
    } else {
      sendCommand(FlightCommands.disarm, "DISARM");
    }
    setIsArmed(false);
  };

  const handleEmergencyStop = () => {
    sendCommand(FlightCommands.emergencyStop, "EMERGENCY STOP");
    setIsArmed(false);
  };

  const EmergencyStopButton = () => (
    <Button
      fullWidth
      variant="contained"
      color="error"
      size="large"
      onClick={handleEmergencyStop}
      startIcon={<Emergency />}
      sx={{
        mb: 2,
        height: 60,
        fontSize: "1.1rem",
        fontWeight: "bold",
        "&:hover": {
          bgcolor: "error.dark",
        },
      }}
    >
      EMERGENCY STOP
    </Button>
  );

  const ArmingControls = () => (
    <Paper elevation={2} sx={{ p: 2, mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        Arming Controls
      </Typography>
      <Box display="flex" alignItems="center" gap={2} mb={2}>
        <Typography variant="body1">Status:</Typography>
        <Chip
          label={isArmed ? "ARMED" : "DISARMED"}
          color={isArmed ? "error" : "success"}
          variant="filled"
        />
        <Chip
          label={safeMode ? "SAFE MODE" : "UNSAFE MODE"}
          color={safeMode ? "success" : "warning"}
          variant="outlined"
        />
      </Box>
      <Box display="flex" alignItems="center" gap={2} mb={2}>
        <FormControlLabel
          control={
            <Switch
              checked={safeMode}
              onChange={(e) => setSafeMode(e.target.checked)}
              color="warning"
            />
          }
          label={
            <Box>
              <Typography variant="body2">
                Safe Mode {safeMode ? "ON" : "OFF"}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {safeMode 
                  ? "Motors maintain minimum safe speed when armed"
                  : "CAUTION: Full power control available"}
              </Typography>
            </Box>
          }
        />
      </Box>
      <Grid container spacing={2}>
        <Grid item xs={6}>
          <Button
            fullWidth
            variant="contained"
            color="warning"
            onClick={handleArm}
            disabled={!isConnected || isArmed}
            startIcon={<FlightTakeoff />}
          >
            ARM
          </Button>
        </Grid>
        <Grid item xs={6}>
          <Button
            fullWidth
            variant="contained"
            color="primary"
            onClick={handleDisarm}
            disabled={!isConnected || !isArmed}
            startIcon={<FlightLand />}
          >
            DISARM
          </Button>
        </Grid>
      </Grid>
    </Paper>
  );

  const HoverControls = () => (
    <Paper elevation={2} sx={{ p: 2, mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        <Height sx={{ mr: 1 }} />
        Hover Controls
      </Typography>

      {/* Preset hover buttons */}
      <Typography variant="subtitle2" gutterBottom>
        Quick Hover Presets:
      </Typography>
      <Grid container spacing={1} sx={{ mb: 2 }}>
        {Object.entries(HOVER_PRESETS).map(([key, preset]) => (
          <Grid item xs={6} sm={3} key={key}>
            <Button
              fullWidth
              variant="outlined"
              size="small"
              onClick={() =>
                sendCommand(
                  () => FlightCommands.hover(preset.value),
                  `Hover ${preset.name}`
                )
              }
              disabled={!isConnected}
            >
              {preset.name}
            </Button>
          </Grid>
        ))}
      </Grid>

      <Divider sx={{ my: 2 }} />

      {/* Custom altitude control */}
      <Typography variant="subtitle2" gutterBottom>
        Custom Altitude: {customAltitude} cm
      </Typography>
      <Box sx={{ mb: 2 }}>
        <Slider
          value={customAltitude}
          onChange={(e, value) => setCustomAltitude(value)}
          min={10}
          max={200}
          step={5}
          marks={[
            { value: 30, label: "30cm" },
            { value: 50, label: "50cm" },
            { value: 100, label: "100cm" },
            { value: 150, label: "150cm" },
            { value: 200, label: "200cm" },
          ]}
          valueLabelDisplay="auto"
          disabled={!isConnected}
        />
      </Box>
      <Button
        fullWidth
        variant="contained"
        color="success"
        onClick={() =>
          sendCommand(
            () => FlightCommands.hover(customAltitude),
            `Hover at ${customAltitude}cm`
          )
        }
        disabled={!isConnected}
      >
        Hover at {customAltitude}cm
      </Button>
    </Paper>
  );

  const ThrottlePercentageControls = () => (
    <Paper elevation={2} sx={{ p: 2, mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        🎛️ Throttle Percentage Control
      </Typography>

      {/* Current throttle percentage display */}
      <Box display="flex" alignItems="center" gap={2} mb={2}>
        <Typography variant="body1">Current Throttle:</Typography>
        <Chip
          label={`${currentThrottlePercentage}%`}
          color={currentThrottlePercentage > 0 ? "primary" : "default"}
          variant="filled"
        />
      </Box>

      {/* Quick increment/decrement buttons */}
      <Typography variant="subtitle2" gutterBottom>
        Quick Adjustments:
      </Typography>
      <Grid container spacing={1} sx={{ mb: 2 }}>
        <Grid item xs={3}>
          <Button
            fullWidth
            variant="contained"
            color="success"
            size="small"
            onClick={() => {
              const newPercentage = Math.min(100, currentThrottlePercentage + 20);
              setCurrentThrottlePercentage(newPercentage);
              sendCommand(
                () => FlightCommands.throttlePercentage(newPercentage),
                `Throttle +20% → ${newPercentage}%`
              );
            }}
            disabled={!isConnected || !isArmed}
          >
            +20%
          </Button>
        </Grid>
        <Grid item xs={3}>
          <Button
            fullWidth
            variant="contained"
            color="success"
            size="small"
            onClick={() => {
              const newPercentage = Math.min(100, currentThrottlePercentage + 5);
              setCurrentThrottlePercentage(newPercentage);
              sendCommand(
                () => FlightCommands.throttlePercentage(newPercentage),
                `Throttle +5% → ${newPercentage}%`
              );
            }}
            disabled={!isConnected || !isArmed}
          >
            +5%
          </Button>
        </Grid>
        <Grid item xs={3}>
          <Button
            fullWidth
            variant="contained"
            color="warning"
            size="small"
            onClick={() => {
              const newPercentage = Math.max(0, currentThrottlePercentage - 5);
              setCurrentThrottlePercentage(newPercentage);
              sendCommand(
                () => FlightCommands.throttlePercentage(newPercentage),
                `Throttle -5% → ${newPercentage}%`
              );
            }}
            disabled={!isConnected || !isArmed}
          >
            -5%
          </Button>
        </Grid>
        <Grid item xs={3}>
          <Button
            fullWidth
            variant="contained"
            color="warning"
            size="small"
            onClick={() => {
              const newPercentage = Math.max(0, currentThrottlePercentage - 20);
              setCurrentThrottlePercentage(newPercentage);
              sendCommand(
                () => FlightCommands.throttlePercentage(newPercentage),
                `Throttle -20% → ${newPercentage}%`
              );
            }}
            disabled={!isConnected || !isArmed}
          >
            -20%
          </Button>
        </Grid>
      </Grid>

      <Divider sx={{ my: 2 }} />

      {/* Manual throttle percentage slider */}
      <Typography variant="subtitle2" gutterBottom>
        Manual Throttle Percentage: {currentThrottlePercentage}%
      </Typography>
      <Box sx={{ mb: 2 }}>
        <Slider
          value={currentThrottlePercentage}
          onChange={(e, value) => setCurrentThrottlePercentage(value)}
          min={0}
          max={100}
          step={1}
          marks={[
            { value: 0, label: "0%" },
            { value: 25, label: "25%" },
            { value: 50, label: "50%" },
            { value: 75, label: "75%" },
            { value: 100, label: "100%" },
          ]}
          valueLabelDisplay="auto"
          disabled={!isConnected}
        />
      </Box>
      <Button
        fullWidth
        variant="contained"
        color="primary"
        onClick={() =>
          sendCommand(
            () => FlightCommands.throttlePercentage(currentThrottlePercentage),
            `Apply Throttle ${currentThrottlePercentage}%`
          )
        }
        disabled={!isConnected || !isArmed}
      >
        Apply Throttle {currentThrottlePercentage}%
      </Button>

      <Box sx={{ mt: 2 }}>
        <Button
          fullWidth
          variant="outlined"
          color="secondary"
          onClick={() => {
            setCurrentThrottlePercentage(0);
            sendCommand(
              () => FlightCommands.throttlePercentage(0),
              "Reset Throttle to 0%"
            );
          }}
          disabled={!isConnected}
        >
          Reset to 0%
        </Button>
      </Box>
    </Paper>
  );

  const MovementControls = () => (
    <Paper elevation={2} sx={{ p: 2, mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        <Speed sx={{ mr: 1 }} />
        Movement Controls
      </Typography>

      {/* Movement intensity slider */}
      <Typography variant="subtitle2" gutterBottom>
        Movement Intensity: {movementIntensity}%
      </Typography>
      <Box sx={{ mb: 2 }}>
        <Slider
          value={movementIntensity}
          onChange={(e, value) => setMovementIntensity(value)}
          min={10}
          max={80}
          step={5}
          marks={Object.values(MOVEMENT_INTENSITIES).map((intensity) => ({
            value: intensity.value,
            label: `${intensity.value}%`,
          }))}
          valueLabelDisplay="auto"
          disabled={!isConnected}
        />
      </Box>

      {/* Directional controls */}
      <Grid container spacing={2}>
        <Grid item xs={12} display="flex" justifyContent="center">
          <Button
            variant="contained"
            onClick={() =>
              sendCommand(
                () => FlightCommands.forward(movementIntensity),
                `Forward ${movementIntensity}%`
              )
            }
            disabled={!isConnected}
            startIcon={<KeyboardArrowUp />}
            sx={{ minWidth: 120 }}
          >
            Forward
          </Button>
        </Grid>

        <Grid item xs={4} display="flex" justifyContent="center">
          <Button
            variant="contained"
            onClick={() =>
              sendCommand(
                () => FlightCommands.left(movementIntensity),
                `Left ${movementIntensity}%`
              )
            }
            disabled={!isConnected}
            startIcon={<KeyboardArrowLeft />}
            sx={{ minWidth: 100 }}
          >
            Left
          </Button>
        </Grid>

        <Grid item xs={4} display="flex" justifyContent="center">
          <Button variant="outlined" disabled sx={{ minWidth: 100 }}>
            Center
          </Button>
        </Grid>

        <Grid item xs={4} display="flex" justifyContent="center">
          <Button
            variant="contained"
            onClick={() =>
              sendCommand(
                () => FlightCommands.right(movementIntensity),
                `Right ${movementIntensity}%`
              )
            }
            disabled={!isConnected}
            startIcon={<KeyboardArrowRight />}
            sx={{ minWidth: 100 }}
          >
            Right
          </Button>
        </Grid>

        <Grid item xs={12} display="flex" justifyContent="center">
          <Button
            variant="contained"
            onClick={() =>
              sendCommand(
                () => FlightCommands.backward(movementIntensity),
                `Backward ${movementIntensity}%`
              )
            }
            disabled={!isConnected}
            startIcon={<KeyboardArrowDown />}
            sx={{ minWidth: 120 }}
          >
            Backward
          </Button>
        </Grid>
      </Grid>

      {/* Yaw controls */}
      <Divider sx={{ my: 2 }} />
      <Typography variant="subtitle2" gutterBottom>
        Yaw Controls:
      </Typography>
      <Grid container spacing={2}>
        <Grid item xs={6}>
          <Button
            fullWidth
            variant="contained"
            color="secondary"
            onClick={() =>
              sendCommand(
                () => FlightCommands.yawLeft(45),
                "Yaw Left 45%"
              )
            }
            disabled={!isConnected}
            sx={{ minWidth: 120 }}
          >
            ↺ Yaw Left
          </Button>
        </Grid>
        <Grid item xs={6}>
          <Button
            fullWidth
            variant="contained"
            color="secondary"
            onClick={() =>
              sendCommand(
                () => FlightCommands.yawRight(45),
                "Yaw Right 45%"
              )
            }
            disabled={!isConnected}
            sx={{ minWidth: 120 }}
          >
            Yaw Right ↻
          </Button>
        </Grid>
      </Grid>
    </Paper>
  );

  const TestControls = () => (
    <Paper elevation={2} sx={{ p: 2, mb: 2 }}>
      <Typography variant="h6" gutterBottom>
        <Build sx={{ mr: 1 }} />
        Test Controls
      </Typography>
      <Alert severity="warning" sx={{ mb: 2 }}>
        <Typography variant="body2">
          <strong>⚠️ SAFETY WARNING:</strong> Remove propellers before testing!
        </Typography>
      </Alert>
      <Button
        fullWidth
        variant="outlined"
        color="warning"
        onClick={() => sendCommand(FlightCommands.test, "Motor Test Sequence")}
        disabled={!isConnected}
      >
        Run Motor Test (No Props!)
      </Button>
    </Paper>
  );

  return (
    <Card elevation={3}>
      <CardContent>
        <Typography variant="h5" component="h2" gutterBottom>
          🚁 Skynet Flight Control
        </Typography>

        {!isConnected && (
          <Alert severity="warning" sx={{ mb: 2 }}>
            Connect to ESP32 to enable flight controls
          </Alert>
        )}

        {lastCommandSent && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Last command: <strong>{lastCommandSent}</strong>
          </Alert>
        )}

        <EmergencyStopButton />
        <ArmingControls />
        <HoverControls />
        <ThrottlePercentageControls />
        <MovementControls />
        <TestControls />
      </CardContent>
    </Card>
  );
};

export default FlightControlPanel;
