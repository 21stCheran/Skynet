#### Flight Controller:
- Software -> ArduPilot
- Hardware -> [[F4 V3S Plus Flight Controller]]

#### Companion Computer:
- Raspberry Pi 4 (possibly)
- iPhone 16 Pro

Establishing a wireless connection to the drone's flight controller using an **ESP32**, we can establish a link using the **MAVLink Protocol**. This setup requires an intensive setup of our own iOS application. This would be extremely demanding.

However using the phone gives us extra components:

- 0.5x 14mm Camera Lens (120 degrees)
- 5x 120mm Camera Lens (Optical Completely)
- Lidar scanner with a 20m accuracy range.
- Onboard powerful processing. 

Using the iPhone and our own custom iOS application we can intensively program autonomous functions. We can identify specific people, identify locations based on GPS, track and identify objects, map 3D space, we can implement obstacle avoidance systems, we can use the flashlight as a beam, etc.


### Control Architecture and Telemetry Link:

###### **Prototype Control Architecture:**
Initially we would use something like QGroundControl to communicate with the drone using the MAVLink Protocol. We can map the inputs of a PS5 DualSense controller to the drone.

###### **Final Control Architecture:**

This requires us to create an advance interface operating between the iPhone, Computer and Drone.

- **Computer (Ground Control Station / Parent Control)**
    - Provides **manual control** or **autonomous mission selection**.
    - Runs a **custom frontend client** (web-based GUI).
    - Communicates with the **backend server** via **WebSockets/HTTP**.
    - Backend then relays commands to the **Drone (via MAVLink)** or **iPhone** depending on the task.

- **Backend Server**
    - Middle layer for communication.
    - Interfaces with both:
        - **Computer** (frontend client).
        - **Drone/iPhone** (through MAVLink + custom protocols).
    - Translates high-level mission commands into **MAVLink messages**.
    - Handles signal routing between **Computer** ↔ **Drone** and **Computer** ↔ **iPhone**.

- **iPhone (Onboard Processor)**
    - Runs **autonomous flight algorithms** (path planning, CV-based navigation, etc.).
    - Communicates with **Drone** over **ESP32 wireless link** (likely Wi-Fi or UART bridge).
    - Receives high-level task requests from **Computer** (via Backend).
    - Executes onboard decisions in near-real time.

- **Drone**
    - Equipped with:
        - **ESP32** (for local wireless link with iPhone).
        - **Telemetry radio** (for MAVLink link with PC/Backend).
    - Accepts commands from both **iPhone** and **Computer**.
    - Flight controller interprets **MAVLink messages** for control/telemetry.



```
Computer <-WebSocket/HTTP-> Backend <-MAVLink-> Drone <-ESP32-> iPhone
```


