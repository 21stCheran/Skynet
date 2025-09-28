/**
 * Flight command utilities for Skynet drone control
 * Matches the JSON command format expected by ESP32 firmware
 * Enhanced with safe motor speed management
 */

export const FLIGHT_COMMANDS = {
  // Basic control
  ARM: "arm",
  DISARM: "disarm",
  EMERGENCY_STOP: "stop",
  SAFE_DISARM: "safe_disarm", // New: Safe disarm with minimum motor speed

  // Movement
  HOVER: "hover",
  SAFE_HOVER: "safe_hover", // New: Hover with minimum safe throttle
  THROTTLE_PERCENTAGE: "throttle_percentage", // New: Direct throttle percentage control
  FORWARD: "forward",
  BACKWARD: "backward",
  LEFT: "left",
  RIGHT: "right",
  YAW_LEFT: "yaw_left", // New: Yaw control
  YAW_RIGHT: "yaw_right", // New: Yaw control

  // Legacy test
  TEST: "test",
};

// Safe flight parameters - prevent complete motor stop
export const SAFE_FLIGHT_PARAMS = {
  THROTTLE_MIN: 1000, // Absolute minimum (motors off)
  THROTTLE_SAFE_MIN: 1200, // Safe minimum (20% above min) - motors always spinning
  THROTTLE_MAX: 2000, // Absolute maximum
  THROTTLE_SAFE_MAX: 1800, // Safe maximum (90% of max)
  THROTTLE_HOVER_BASE: 1450, // Base hover throttle
  MOVEMENT_MAX_SAFE: 60, // Maximum movement intensity in safe mode
  MOVEMENT_MAX_UNSAFE: 80, // Maximum movement intensity in unsafe mode
  THROTTLE_PERCENTAGE_MIN: 0, // Minimum throttle percentage
  THROTTLE_PERCENTAGE_MAX: 100, // Maximum throttle percentage
  THROTTLE_PERCENTAGE_SAFE_MIN: 20, // Minimum safe throttle percentage (20% = 1200)
  THROTTLE_PERCENTAGE_SAFE_MAX: 80, // Maximum safe throttle percentage (80% = 1800)
};

export const HOVER_PRESETS = {
  SAFE_LOW: { name: "Safe Low (30cm)", value: 30, throttle: 1250 },
  LOW: { name: "Low (30cm)", value: 30, throttle: 1300 },
  MEDIUM: { name: "Medium (50cm)", value: 50, throttle: 1450 },
  HIGH: { name: "High (100cm)", value: 100, throttle: 1600 },
  VERY_HIGH: { name: "Very High (150cm)", value: 150, throttle: 1750 },
};

export const MOVEMENT_INTENSITIES = {
  SAFE: { name: "Safe (15%)", value: 15 },
  GENTLE: { name: "Gentle (20%)", value: 20 },
  NORMAL: { name: "Normal (30%)", value: 30 },
  AGGRESSIVE: { name: "Aggressive (50%)", value: 50 },
  MAXIMUM: { name: "Maximum (80%)", value: 80 },
};

/**
 * Creates a flight command JSON object with safety checks
 * @param {string} command - Command type
 * @param {number} value - Command value
 * @param {boolean} safeMode - Whether to apply safe limits
 * @returns {string} JSON command string
 */
export const createFlightCommand = (command, value = 0, safeMode = true) => {
  let safeValue = value;

  // Apply safety limits based on command type
  if (safeMode) {
    switch (command) {
      case FLIGHT_COMMANDS.HOVER:
      case FLIGHT_COMMANDS.SAFE_HOVER:
        // Ensure hover throttle is within safe range
        if (typeof value === "number" && value >= 1000 && value <= 2000) {
          // Value is throttle PWM value
          safeValue = Math.max(
            SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MIN,
            Math.min(value, SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MAX)
          );
        } else {
          // Value is altitude in cm, convert to safe throttle
          const altitudeThrottle =
            SAFE_FLIGHT_PARAMS.THROTTLE_HOVER_BASE + value * 2;
          safeValue = Math.max(
            SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MIN,
            Math.min(altitudeThrottle, SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MAX)
          );
        }
        break;

      case FLIGHT_COMMANDS.THROTTLE_PERCENTAGE:
        // Ensure throttle percentage is within safe range (20%-80% in safe mode)
        safeValue = Math.max(
          SAFE_FLIGHT_PARAMS.THROTTLE_PERCENTAGE_SAFE_MIN,
          Math.min(value, SAFE_FLIGHT_PARAMS.THROTTLE_PERCENTAGE_SAFE_MAX)
        );
        break;

      case FLIGHT_COMMANDS.FORWARD:
      case FLIGHT_COMMANDS.BACKWARD:
      case FLIGHT_COMMANDS.LEFT:
      case FLIGHT_COMMANDS.RIGHT:
      case FLIGHT_COMMANDS.YAW_LEFT:
      case FLIGHT_COMMANDS.YAW_RIGHT:
        // Limit movement intensity in safe mode
        safeValue = Math.min(value, SAFE_FLIGHT_PARAMS.MOVEMENT_MAX_SAFE);
        break;

      case FLIGHT_COMMANDS.EMERGENCY_STOP:
        // Emergency stop always goes to minimum for immediate safety
        safeValue = 0;
        break;

      case FLIGHT_COMMANDS.SAFE_DISARM:
        // Safe disarm maintains minimum motor speed briefly before full stop
        safeValue = SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MIN;
        break;
    }
  }

  const commandObj = {
    command: command,
    value: safeValue,
    safeMode: safeMode,
    timestamp: Date.now(),
  };
  return JSON.stringify(commandObj);
};

/**
 * Pre-built command generators with safety enhancements
 */
export const FlightCommands = {
  // Basic control
  arm: (safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.ARM, 1, safeMode),
  disarm: (safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.DISARM, 0, safeMode),
  safeDisarm: () =>
    createFlightCommand(
      FLIGHT_COMMANDS.SAFE_DISARM,
      SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MIN,
      true
    ),
  emergencyStop: () =>
    createFlightCommand(FLIGHT_COMMANDS.EMERGENCY_STOP, 0, false), // Never safe mode for emergency

  // Hover commands
  hover: (altitudeCm, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.HOVER, altitudeCm, safeMode),
  safeHover: (altitudeCm) =>
    createFlightCommand(FLIGHT_COMMANDS.SAFE_HOVER, altitudeCm, true),
  hoverThrottle: (throttleValue, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.HOVER, throttleValue, safeMode),

  // Preset hover commands
  hoverSafeLow: () =>
    createFlightCommand(
      FLIGHT_COMMANDS.SAFE_HOVER,
      HOVER_PRESETS.SAFE_LOW.throttle,
      true
    ),
  hoverLow: (safeMode = true) =>
    createFlightCommand(
      FLIGHT_COMMANDS.HOVER,
      HOVER_PRESETS.LOW.throttle,
      safeMode
    ),
  hoverMedium: (safeMode = true) =>
    createFlightCommand(
      FLIGHT_COMMANDS.HOVER,
      HOVER_PRESETS.MEDIUM.throttle,
      safeMode
    ),
  hoverHigh: (safeMode = true) =>
    createFlightCommand(
      FLIGHT_COMMANDS.HOVER,
      HOVER_PRESETS.HIGH.throttle,
      safeMode
    ),

  // Movement commands
  forward: (intensity, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.FORWARD, intensity, safeMode),
  backward: (intensity, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.BACKWARD, intensity, safeMode),
  left: (intensity, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.LEFT, intensity, safeMode),
  right: (intensity, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.RIGHT, intensity, safeMode),

  // Yaw commands (new)
  yawLeft: (intensity, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.YAW_LEFT, intensity, safeMode),
  yawRight: (intensity, safeMode = true) =>
    createFlightCommand(FLIGHT_COMMANDS.YAW_RIGHT, intensity, safeMode),

  // Throttle percentage commands (new)
  throttlePercentage: (percentage, safeMode = true) =>
    createFlightCommand(
      FLIGHT_COMMANDS.THROTTLE_PERCENTAGE,
      percentage,
      safeMode
    ),

  // Xbox controller specific commands
  xbox: {
    throttle: (stickValue, safeMode = true) => {
      // Convert stick value (-1 to 1) to throttle (1200-1800 in safe mode, 1000-2000 in unsafe)
      const range = safeMode
        ? SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MAX -
          SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MIN
        : SAFE_FLIGHT_PARAMS.THROTTLE_MAX - SAFE_FLIGHT_PARAMS.THROTTLE_MIN;
      const baseThrottle = safeMode
        ? SAFE_FLIGHT_PARAMS.THROTTLE_SAFE_MIN
        : SAFE_FLIGHT_PARAMS.THROTTLE_MIN;
      const throttle = baseThrottle + ((stickValue + 1) / 2) * range;
      return createFlightCommand(
        FLIGHT_COMMANDS.HOVER,
        Math.round(throttle),
        safeMode
      );
    },

    movement: (direction, stickValue, safeMode = true) => {
      const maxIntensity = safeMode
        ? SAFE_FLIGHT_PARAMS.MOVEMENT_MAX_SAFE
        : SAFE_FLIGHT_PARAMS.MOVEMENT_MAX_UNSAFE;
      const intensity = Math.abs(stickValue) * maxIntensity;
      return createFlightCommand(
        FLIGHT_COMMANDS[direction.toUpperCase()],
        Math.round(intensity),
        safeMode
      );
    },
  },

  // Legacy test command (string, not JSON)
  test: () => "test",
};

/**
 * Validates a flight command
 * @param {string} command - Command type
 * @param {number} value - Command value
 * @returns {object} Validation result with isValid and error
 */
export const validateFlightCommand = (command, value) => {
  const result = { isValid: true, error: null };

  if (!Object.values(FLIGHT_COMMANDS).includes(command)) {
    result.isValid = false;
    result.error = `Unknown command: ${command}`;
    return result;
  }

  // Validate value ranges
  switch (command) {
    case FLIGHT_COMMANDS.HOVER:
      if (value < 10 || value > 300) {
        result.isValid = false;
        result.error = "Hover altitude must be between 10-300 cm";
      }
      break;

    case FLIGHT_COMMANDS.THROTTLE_PERCENTAGE:
      if (value < 0 || value > 100) {
        result.isValid = false;
        result.error = "Throttle percentage must be between 0-100%";
      }
      break;

    case FLIGHT_COMMANDS.FORWARD:
    case FLIGHT_COMMANDS.BACKWARD:
    case FLIGHT_COMMANDS.LEFT:
    case FLIGHT_COMMANDS.RIGHT:
    case FLIGHT_COMMANDS.YAW_LEFT:
    case FLIGHT_COMMANDS.YAW_RIGHT:
      if (value < 10 || value > 100) {
        result.isValid = false;
        result.error = "Movement intensity must be between 10-100%";
      }
      break;
  }

  return result;
};

/**
 * Gets the expected RC channel behavior for a command
 * @param {string} command - Command type
 * @param {number} value - Command value
 * @returns {string} Description of expected behavior
 */
export const getCommandDescription = (command, value) => {
  switch (command) {
    case FLIGHT_COMMANDS.ARM:
      return "Sets AUX1 to 2000 (Armed state)";
    case FLIGHT_COMMANDS.DISARM:
      return "Sets AUX1 to 1000 (Disarmed), cuts throttle";
    case FLIGHT_COMMANDS.SAFE_DISARM:
      return "Gradually reduces throttle with minimum motor speed maintenance";
    case FLIGHT_COMMANDS.EMERGENCY_STOP:
      return "Immediately cuts throttle and disarms";
    case FLIGHT_COMMANDS.HOVER:
      return `Sets throttle to ~${1450 + value * 2} for ${value}cm hover`;
    case FLIGHT_COMMANDS.THROTTLE_PERCENTAGE: {
      const rcValue = Math.round(1000 + value * 10); // 0% = 1000, 100% = 2000
      return `Sets throttle to ${rcValue} (${value}% power)`;
    }
    case FLIGHT_COMMANDS.FORWARD:
      return `Sets pitch to ${1500 + Math.floor(value * 3)} (forward movement)`;
    case FLIGHT_COMMANDS.BACKWARD:
      return `Sets pitch to ${
        1500 - Math.floor(value * 3)
      } (backward movement)`;
    case FLIGHT_COMMANDS.LEFT:
      return `Sets roll to ${1500 - Math.floor(value * 3)} (left movement)`;
    case FLIGHT_COMMANDS.RIGHT:
      return `Sets roll to ${1500 + Math.floor(value * 3)} (right movement)`;
    case FLIGHT_COMMANDS.YAW_LEFT:
      return `Sets yaw to ${1500 - Math.floor(value * 3)} (yaw left)`;
    case FLIGHT_COMMANDS.YAW_RIGHT:
      return `Sets yaw to ${1500 + Math.floor(value * 3)} (yaw right)`;
    default:
      return "Unknown command behavior";
  }
};
