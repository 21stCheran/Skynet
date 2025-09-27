/**
 * Flight command utilities for Skynet drone control
 * Matches the JSON command format expected by ESP32 firmware
 */

export const FLIGHT_COMMANDS = {
  // Basic control
  ARM: "arm",
  DISARM: "disarm",
  EMERGENCY_STOP: "stop",

  // Movement
  HOVER: "hover",
  FORWARD: "forward",
  BACKWARD: "backward",
  LEFT: "left",
  RIGHT: "right",

  // Legacy test
  TEST: "test",
};

export const HOVER_PRESETS = {
  LOW: { name: "Low (30cm)", value: 30 },
  MEDIUM: { name: "Medium (50cm)", value: 50 },
  HIGH: { name: "High (100cm)", value: 100 },
  VERY_HIGH: { name: "Very High (150cm)", value: 150 },
};

export const MOVEMENT_INTENSITIES = {
  GENTLE: { name: "Gentle (20%)", value: 20 },
  NORMAL: { name: "Normal (30%)", value: 30 },
  AGGRESSIVE: { name: "Aggressive (50%)", value: 50 },
  MAXIMUM: { name: "Maximum (80%)", value: 80 },
};

/**
 * Creates a flight command JSON object
 * @param {string} command - Command type
 * @param {number} value - Command value
 * @returns {string} JSON command string
 */
export const createFlightCommand = (command, value = 0) => {
  const commandObj = {
    command: command,
    value: value,
  };
  return JSON.stringify(commandObj);
};

/**
 * Pre-built command generators
 */
export const FlightCommands = {
  arm: () => createFlightCommand(FLIGHT_COMMANDS.ARM, 1),
  disarm: () => createFlightCommand(FLIGHT_COMMANDS.DISARM, 0),
  emergencyStop: () => createFlightCommand(FLIGHT_COMMANDS.EMERGENCY_STOP, 0),

  hover: (altitudeCm) => createFlightCommand(FLIGHT_COMMANDS.HOVER, altitudeCm),
  hoverLow: () =>
    createFlightCommand(FLIGHT_COMMANDS.HOVER, HOVER_PRESETS.LOW.value),
  hoverMedium: () =>
    createFlightCommand(FLIGHT_COMMANDS.HOVER, HOVER_PRESETS.MEDIUM.value),
  hoverHigh: () =>
    createFlightCommand(FLIGHT_COMMANDS.HOVER, HOVER_PRESETS.HIGH.value),

  forward: (intensity) =>
    createFlightCommand(FLIGHT_COMMANDS.FORWARD, intensity),
  backward: (intensity) =>
    createFlightCommand(FLIGHT_COMMANDS.BACKWARD, intensity),
  left: (intensity) => createFlightCommand(FLIGHT_COMMANDS.LEFT, intensity),
  right: (intensity) => createFlightCommand(FLIGHT_COMMANDS.RIGHT, intensity),

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

    case FLIGHT_COMMANDS.FORWARD:
    case FLIGHT_COMMANDS.BACKWARD:
    case FLIGHT_COMMANDS.LEFT:
    case FLIGHT_COMMANDS.RIGHT:
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
    case FLIGHT_COMMANDS.EMERGENCY_STOP:
      return "Immediately cuts throttle and disarms";
    case FLIGHT_COMMANDS.HOVER:
      return `Sets throttle to ~${1450 + value * 2} for ${value}cm hover`;
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
    default:
      return "Unknown command behavior";
  }
};
