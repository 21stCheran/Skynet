import React, { useState, useEffect, useCallback } from "react";
import {
  Card,
  CardContent,
  Typography,
  Button,
  Box,
  Grid,
  Alert,
  Switch,
  FormControlLabel,
  Chip,
  Paper,
  LinearProgress,
} from "@mui/material";
import {
  SportsEsports,
  FlightTakeoff,
  Security,
  Speed,
  Height,
} from "@mui/icons-material";

const XboxController = ({
  isConnected,
  onSendCommand,
  isArmed,
  setIsArmed,
}) => {
  const [gamepadConnected, setGamepadConnected] = useState(false);
  const [gamepadIndex, setGamepadIndex] = useState(-1);
  const [controllerEnabled, setControllerEnabled] = useState(false);
  const [safeMode, setSafeMode] = useState(true);
  const [lastCommand, setLastCommand] = useState("");
  const [controllerState, setControllerState] = useState({
    leftStick: { x: 0, y: 0 },
    rightStick: { x: 0, y: 0 },
    triggers: { left: 0, right: 0 },
    buttons: {},
  });
  const [previousButtons, setPreviousButtons] = useState({});
  const [previousControllerState, setPreviousControllerState] = useState({
    leftStick: { x: 0, y: 0 },
    rightStick: { x: 0, y: 0 },
    triggers: { left: 0, right: 0 },
  });
  const [lastCommandTime, setLastCommandTime] = useState(0);
  const [performanceStats, setPerformanceStats] = useState({
    updateRate: 0,
    commandRate: 0,
    inputLag: 0,
  });
  const [performanceInterval, setPerformanceInterval] = useState(null);

  // Safe flight parameters
  const SAFE_THROTTLE_MIN = 1200; // Minimum safe throttle (20% above min)
  const SAFE_THROTTLE_MAX = 1800; // Maximum safe throttle (90% of max)
  const SAFE_MOVEMENT_MAX = 60; // Maximum movement intensity in safe mode
  const DEADZONE = 0.05; // Reduced deadzone for more responsive control
  const UPDATE_RATE = 16; // 16ms = ~60Hz update rate (much more responsive)
  const COMMAND_THROTTLE_RATE = 33; // 33ms = 30Hz command sending (balanced for network)

  // Controller button mapping
  const BUTTON_MAP = {
    A: 0, // Xbox A - Arm/Disarm
    B: 1, // Xbox B - Emergency Stop
    X: 2, // Xbox X - Toggle Safe Mode
    Y: 3, // Xbox Y - Auto Hover
    LB: 4, // Left Bumper
    RB: 5, // Right Bumper
    LT: 6, // Left Trigger (as button)
    RT: 7, // Right Trigger (as button)
    BACK: 8, // Back/Select
    START: 9, // Start/Menu
    LS: 10, // Left Stick Click
    RS: 11, // Right Stick Click
    DPAD_UP: 12,
    DPAD_DOWN: 13,
    DPAD_LEFT: 14,
    DPAD_RIGHT: 15,
  };

  // Apply deadzone with smooth curve for better control feel
  const applyDeadzone = useCallback((value) => {
    if (Math.abs(value) < DEADZONE) return 0;
    
    // Apply smooth curve: remove deadzone and rescale to full range
    const sign = Math.sign(value);
    const magnitude = Math.abs(value);
    const adjustedMagnitude = (magnitude - DEADZONE) / (1 - DEADZONE);
    
    // Apply slight exponential curve for better control precision
    const curvedValue = Math.pow(adjustedMagnitude, 1.2);
    
    return sign * curvedValue;
  }, []);

  // Input smoothing filter to reduce jitter
  const smoothInput = useCallback((newValue, oldValue, smoothingFactor = 0.3) => {
    if (Math.abs(newValue) < 0.01) return newValue; // Don't smooth zero values
    return oldValue * (1 - smoothingFactor) + newValue * smoothingFactor;
  }, []);

  // Check if input has changed significantly to avoid spam
  const hasSignificantChange = useCallback((current, previous, threshold = 0.015) => {
    return Math.abs(current.leftStick.x - previous.leftStick.x) > threshold ||
           Math.abs(current.leftStick.y - previous.leftStick.y) > threshold ||
           Math.abs(current.rightStick.x - previous.rightStick.x) > threshold ||
           Math.abs(current.rightStick.y - previous.rightStick.y) > threshold ||
           Math.abs(current.triggers.left - previous.triggers.left) > threshold ||
           Math.abs(current.triggers.right - previous.triggers.right) > threshold;
  }, []);

  // Convert stick values to safe ranges
  const mapStickToThrottle = useCallback((stickValue) => {
    if (!safeMode) {
      // Full range in unsafe mode
      return Math.round(1000 + (stickValue + 1) * 500); // 1000-2000
    }
    // Safe range
    const range = SAFE_THROTTLE_MAX - SAFE_THROTTLE_MIN;
    return Math.round(SAFE_THROTTLE_MIN + (stickValue + 1) * (range / 2));
  }, [safeMode]);

  const mapStickToMovement = useCallback((stickValue) => {
    const maxIntensity = safeMode ? SAFE_MOVEMENT_MAX : 80;
    return Math.round(Math.abs(stickValue) * maxIntensity);
  }, [safeMode]);

  // Send flight command with safety checks
  const sendSafeCommand = useCallback((command, value, description) => {
    if (!isConnected || !controllerEnabled) return;

    // Apply safe limits
    let safeValue = value;
    if (command === "hover") {
      // Ensure hover throttle includes minimum motor speed
      safeValue = Math.max(value, SAFE_THROTTLE_MIN);
    } else if (["forward", "backward", "left", "right"].includes(command)) {
      // Limit movement intensity in safe mode
      const maxIntensity = safeMode ? SAFE_MOVEMENT_MAX : 80;
      safeValue = Math.min(value, maxIntensity);
    }

    const commandJson = JSON.stringify({ command, value: safeValue });
    onSendCommand(commandJson);
    setLastCommand(description);
  }, [isConnected, controllerEnabled, safeMode, onSendCommand]);

  // Process gamepad input
  const processGamepadInput = useCallback(() => {
    if (!gamepadConnected || gamepadIndex === -1 || !controllerEnabled) return;

    const gamepad = navigator.getGamepads()[gamepadIndex];
    if (!gamepad) return;

    // Get raw stick values with deadzone
    const rawLeftStickX = applyDeadzone(gamepad.axes[0]); // Roll
    const rawLeftStickY = applyDeadzone(-gamepad.axes[1]); // Pitch (inverted)
    const rawRightStickX = applyDeadzone(gamepad.axes[2]); // Yaw
    const rawRightStickY = applyDeadzone(-gamepad.axes[3]); // Throttle (inverted)

    // Apply smoothing to reduce jitter (except for throttle which should be immediate)
    const leftStickX = smoothInput(rawLeftStickX, previousControllerState.leftStick.x, 0.4);
    const leftStickY = smoothInput(rawLeftStickY, previousControllerState.leftStick.y, 0.4);
    const rightStickX = smoothInput(rawRightStickX, previousControllerState.rightStick.x, 0.4);
    const rightStickY = rawRightStickY; // Keep throttle immediate for safety

    // Get trigger values (smooth for fine control)
    const rawLeftTrigger = gamepad.buttons[6]?.value || 0;
    const rawRightTrigger = gamepad.buttons[7]?.value || 0;
    const leftTrigger = smoothInput(rawLeftTrigger, previousControllerState.triggers.left, 0.3);
    const rightTrigger = smoothInput(rawRightTrigger, previousControllerState.triggers.right, 0.3);

    // Current input state
    const currentInputState = {
      leftStick: { x: leftStickX, y: leftStickY },
      rightStick: { x: rightStickX, y: rightStickY },
      triggers: { left: leftTrigger, right: rightTrigger },
    };

    // Update visual controller state (always update for UI feedback)
    setControllerState({
      ...currentInputState,
      buttons: gamepad.buttons.reduce((acc, button, index) => {
        acc[index] = button.pressed;
        return acc;
      }, {}),
    });

    // Check if we should send commands (throttle to avoid network spam)
    const now = Date.now();
    const timeSinceLastCommand = now - lastCommandTime;
    const hasInputChanged = hasSignificantChange(currentInputState, previousControllerState);
    
    // Only send commands if input changed significantly OR enough time has passed
    const shouldSendCommand = hasInputChanged || timeSinceLastCommand > COMMAND_THROTTLE_RATE;

    // Process button presses (only on press, not hold)
    const currentButtons = gamepad.buttons.reduce((acc, button, index) => {
      acc[index] = button.pressed;
      return acc;
    }, {});
    
    // A Button - Toggle Arm/Disarm
    if (gamepad.buttons[BUTTON_MAP.A]?.pressed && !previousButtons[BUTTON_MAP.A]) {
      if (isArmed) {
        sendSafeCommand("disarm", 0, "Xbox A - Disarm");
        setIsArmed(false);
      } else {
        sendSafeCommand("arm", 1, "Xbox A - Arm");
        setIsArmed(true);
      }
    }

    // B Button - Emergency Stop
    if (gamepad.buttons[BUTTON_MAP.B]?.pressed && !previousButtons[BUTTON_MAP.B]) {
      sendSafeCommand("stop", 0, "Xbox B - Emergency Stop");
      setIsArmed(false);
    }

    // X Button - Toggle Safe Mode
    if (gamepad.buttons[BUTTON_MAP.X]?.pressed && !previousButtons[BUTTON_MAP.X]) {
      setSafeMode(!safeMode);
    }

    // Y Button - Auto Hover at safe altitude
    if (gamepad.buttons[BUTTON_MAP.Y]?.pressed && !previousButtons[BUTTON_MAP.Y]) {
      sendSafeCommand("hover", 50, "Xbox Y - Auto Hover 50cm");
    }

    // Store previous button states
    setPreviousButtons(currentButtons);

    // Process continuous movement controls (only when armed and should send command)
    if (isArmed && shouldSendCommand) {
      let commandSent = false;

      // Throttle control (Right stick Y-axis + triggers)
      if (Math.abs(rightStickY) > 0 || rightTrigger > 0.05 || leftTrigger > 0.05) {
        const baseThrottle = mapStickToThrottle(rightStickY);
        const triggerAdjustment = (rightTrigger - leftTrigger) * 100;
        const finalThrottle = Math.max(SAFE_THROTTLE_MIN, baseThrottle + triggerAdjustment);
        sendSafeCommand("safe_hover", finalThrottle, `Throttle: ${finalThrottle}`);
        commandSent = true;
      }

      // Movement controls (Left stick) - Send combined movement command
      if (Math.abs(leftStickX) > 0 || Math.abs(leftStickY) > 0) {
        // Prioritize the larger input to avoid conflicting commands
        if (Math.abs(leftStickX) > Math.abs(leftStickY)) {
          const intensity = mapStickToMovement(leftStickX);
          const direction = leftStickX > 0 ? "right" : "left";
          sendSafeCommand(direction, intensity, `${direction} ${intensity}%`);
        } else {
          const intensity = mapStickToMovement(leftStickY);
          const direction = leftStickY > 0 ? "forward" : "backward";
          sendSafeCommand(direction, intensity, `${direction} ${intensity}%`);
        }
        commandSent = true;
      }

      // Yaw control (Right stick X-axis)
      if (Math.abs(rightStickX) > 0) {
        const intensity = mapStickToMovement(rightStickX);
        const direction = rightStickX > 0 ? "yaw_right" : "yaw_left";
        sendSafeCommand(direction, intensity, `Yaw ${direction} ${intensity}%`);
        commandSent = true;
      }

      // Update timing and state tracking if command was sent
      if (commandSent) {
        setLastCommandTime(now);
        setPreviousControllerState(currentInputState);
      }
    }
  }, [gamepadConnected, gamepadIndex, controllerEnabled, isArmed, safeMode, 
      applyDeadzone, smoothInput, mapStickToThrottle, mapStickToMovement, sendSafeCommand, setIsArmed,
      hasSignificantChange, previousControllerState, lastCommandTime]);

  // Gamepad detection and connection
  useEffect(() => {
    const checkGamepads = () => {
      const gamepads = navigator.getGamepads();
      let found = false;
      let foundIndex = -1;

      for (let i = 0; i < gamepads.length; i++) {
        if (gamepads[i] && gamepads[i].id.toLowerCase().includes("xbox")) {
          found = true;
          foundIndex = i;
          break;
        }
      }

      setGamepadConnected(found);
      setGamepadIndex(foundIndex);
    };

    // Check initially
    checkGamepads();

    // Listen for gamepad events
    const handleGamepadConnected = (e) => {
      console.log("Gamepad connected:", e.gamepad.id);
      checkGamepads();
    };

    const handleGamepadDisconnected = (e) => {
      console.log("Gamepad disconnected:", e.gamepad.id);
      checkGamepads();
      setControllerEnabled(false); // Disable for safety
    };

    window.addEventListener("gamepadconnected", handleGamepadConnected);
    window.addEventListener("gamepaddisconnected", handleGamepadDisconnected);

    return () => {
      window.removeEventListener("gamepadconnected", handleGamepadConnected);
      window.removeEventListener("gamepaddisconnected", handleGamepadDisconnected);
    };
  }, []);

  // Performance monitoring
  useEffect(() => {
    if (!controllerEnabled) return;

    let updateCount = 0;
    let commandCount = 0;
    let lastUpdateTime = Date.now();

    const perfInterval = setInterval(() => {
      const now = Date.now();
      const deltaTime = (now - lastUpdateTime) / 1000;
      
      setPerformanceStats({
        updateRate: Math.round(updateCount / deltaTime),
        commandRate: Math.round(commandCount / deltaTime),
        inputLag: UPDATE_RATE,
      });
      
      updateCount = 0;
      commandCount = 0;
      lastUpdateTime = now;
    }, 1000);

    setPerformanceInterval(perfInterval);
    return () => clearInterval(perfInterval);
  }, [controllerEnabled]);

  // Gamepad polling loop - OPTIMIZED for 60Hz
  useEffect(() => {
    if (!controllerEnabled) return;

    const interval = setInterval(processGamepadInput, UPDATE_RATE);
    return () => clearInterval(interval);
  }, [controllerEnabled, processGamepadInput]);

  return (
    <Card elevation={3}>
      <CardContent>
        <Typography variant="h5" component="h2" gutterBottom>
          <SportsEsports sx={{ mr: 1 }} />
          Xbox Controller
        </Typography>

        {!isConnected && (
          <Alert severity="warning" sx={{ mb: 2 }}>
            Connect to ESP32 to enable controller
          </Alert>
        )}

        {/* Controller Status */}
        <Paper elevation={1} sx={{ p: 2, mb: 2 }}>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} sm={6}>
              <Box display="flex" alignItems="center" gap={1}>
                <Typography variant="body1">Controller:</Typography>
                <Chip
                  label={gamepadConnected ? "CONNECTED" : "DISCONNECTED"}
                  color={gamepadConnected ? "success" : "error"}
                  size="small"
                />
              </Box>
            </Grid>
            <Grid item xs={12} sm={6}>
              <FormControlLabel
                control={
                  <Switch
                    checked={controllerEnabled}
                    onChange={(e) => setControllerEnabled(e.target.checked)}
                    disabled={!gamepadConnected || !isConnected}
                  />
                }
                label="Enable Control"
              />
            </Grid>
          </Grid>
        </Paper>

        {/* Safety Settings */}
        <Paper elevation={1} sx={{ p: 2, mb: 2 }}>
          <Typography variant="h6" gutterBottom>
            <Security sx={{ mr: 1 }} />
            Safety Settings
          </Typography>
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
                    ? `Limits: Throttle ${SAFE_THROTTLE_MIN}-${SAFE_THROTTLE_MAX}, Movement ${SAFE_MOVEMENT_MAX}%`
                    : "CAUTION: Full power available"}
                </Typography>
              </Box>
            }
          />
        </Paper>

        {/* Control Mapping */}
        <Paper elevation={1} sx={{ p: 2, mb: 2 }}>
          <Typography variant="h6" gutterBottom>
            Control Mapping
          </Typography>
          <Grid container spacing={1}>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>Left Stick:</strong> Roll/Pitch
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>Right Stick:</strong> Throttle/Yaw
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>A Button:</strong> Arm/Disarm
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>B Button:</strong> Emergency Stop
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>X Button:</strong> Toggle Safe Mode
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>Y Button:</strong> Auto Hover
              </Typography>
            </Grid>
            <Grid item xs={6}>
              <Typography variant="body2">
                <strong>Triggers:</strong> Throttle Fine Control
              </Typography>
            </Grid>
          </Grid>
        </Paper>

        {/* Live Controller State */}
        {controllerEnabled && gamepadConnected && (
          <Paper elevation={1} sx={{ p: 2, mb: 2 }}>
            <Typography variant="h6" gutterBottom>
              Live Controller State
            </Typography>
            <Grid container spacing={2}>
              <Grid item xs={6}>
                <Typography variant="body2">Left Stick:</Typography>
                <Typography variant="caption">
                  X: {controllerState.leftStick.x.toFixed(2)}, 
                  Y: {controllerState.leftStick.y.toFixed(2)}
                </Typography>
                <LinearProgress 
                  variant="determinate" 
                  value={(controllerState.leftStick.x + 1) * 50} 
                  sx={{ mb: 1 }}
                />
                <LinearProgress 
                  variant="determinate" 
                  value={(controllerState.leftStick.y + 1) * 50} 
                />
              </Grid>
              <Grid item xs={6}>
                <Typography variant="body2">Right Stick:</Typography>
                <Typography variant="caption">
                  X: {controllerState.rightStick.x.toFixed(2)}, 
                  Y: {controllerState.rightStick.y.toFixed(2)}
                </Typography>
                <LinearProgress 
                  variant="determinate" 
                  value={(controllerState.rightStick.x + 1) * 50} 
                  sx={{ mb: 1 }}
                />
                <LinearProgress 
                  variant="determinate" 
                  value={(controllerState.rightStick.y + 1) * 50} 
                />
              </Grid>
              <Grid item xs={6}>
                <Typography variant="body2">Left Trigger:</Typography>
                <LinearProgress 
                  variant="determinate" 
                  value={controllerState.triggers.left * 100} 
                />
              </Grid>
              <Grid item xs={6}>
                <Typography variant="body2">Right Trigger:</Typography>
                <LinearProgress 
                  variant="determinate" 
                  value={controllerState.triggers.right * 100} 
                />
              </Grid>
            </Grid>
          </Paper>
        )}

        {/* Performance Stats */}
        {controllerEnabled && (
          <Paper elevation={1} sx={{ p: 2, mb: 2 }}>
            <Typography variant="h6" gutterBottom>
              <Speed sx={{ mr: 1 }} />
              Performance Stats
            </Typography>
            <Grid container spacing={2}>
              <Grid item xs={4}>
                <Typography variant="body2">Update Rate:</Typography>
                <Typography variant="h6" color="primary">
                  {performanceStats.updateRate}Hz
                </Typography>
              </Grid>
              <Grid item xs={4}>
                <Typography variant="body2">Command Rate:</Typography>
                <Typography variant="h6" color="success.main">
                  {performanceStats.commandRate}Hz
                </Typography>
              </Grid>
              <Grid item xs={4}>
                <Typography variant="body2">Input Lag:</Typography>
                <Typography variant="h6" color="warning.main">
                  {performanceStats.inputLag}ms
                </Typography>
              </Grid>
            </Grid>
          </Paper>
        )}

        {/* Last Command */}
        {lastCommand && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Last command: <strong>{lastCommand}</strong>
          </Alert>
        )}

        {/* Instructions */}
        <Paper elevation={1} sx={{ p: 2 }}>
          <Typography variant="h6" gutterBottom>
            Safety Instructions
          </Typography>
          <Typography variant="body2" paragraph>
            • Always keep Safe Mode ON during initial flights
          </Typography>
          <Typography variant="body2" paragraph>
            • B button (Emergency Stop) immediately cuts power
          </Typography>
          <Typography variant="body2" paragraph>
            • Motors maintain minimum safe speed when armed
          </Typography>
          <Typography variant="body2" paragraph>
            • Connect Xbox controller before enabling control
          </Typography>
        </Paper>
      </CardContent>
    </Card>
  );
};

export default XboxController;