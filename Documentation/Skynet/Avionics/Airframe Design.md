Frames for the final drone would be better built with hybrid materials for different components.

### Component Selection and Sourcing (AUW ≈ 2kg)

With an estimated AUW of 2 kg (includes payload) and a target TWR of 2:1, the propulsion system must generate a total of 4 kg of thrust, or 1 kg per motor.

- **[[Motor]]s:** For a 450mm-class frame, common motor sizes include 2212, 2216, and 2312. A KV rating between 900-1400KV is appropriate when paired with 9- to 10-inch propellers and a 4S battery system.
- **Propellers:** 10-inch propellers, such as the widely available 1045 (10-inch diameter, 4.5-inch pitch) models, offer a good balance of thrust and efficiency for this frame size and weight class.
- **ESCs:** To ensure a safe operational margin, 30A or 40A ESCs would be preferential. This rating should be comfortably above the maximum current draw specified in the motor's performance data for the chosen propeller and voltage.
- **[[Battery]]:** A 3S1P battery


#### Current Configuration:
- Frame -> [[F450 Q450 Quadcopter Frame]]
- Motor -> [[A2212 1000 KV BLDC Brushless DC Motor]]
- Propeller -> [[Pro-Range Propellers 1045(10X4.5) Glass Fiber Nylon White 1CW+1CCW-1pair]]
- Flight Controller -> [[F4 V3S Plus Flight Controller]]
- Flight Controller Firmware -> ArduPilot
- Companion Computer -> Raspberry Pi 4 + iPhone 16 Pro
- ESC -> [[SimonK 30A ESC]]
- Telemetry Radio ->[[2.4GHz NRF24L01+PA+LNA SMA Wireless Transceiver Antenna]]
- Controller Radio -> [[2.4GHz NRF24L01+PA+LNA SMA Wireless Transceiver Antenna]]
- GPS Module -> [[NEO-6M GPS Module with EPROM]]
- PDB -> 