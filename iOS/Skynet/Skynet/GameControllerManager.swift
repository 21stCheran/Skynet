//
//  GameControllerManager.swift
//  Skynet
//

import Foundation
import GameController
import Combine

class GameControllerManager: ObservableObject {
    @Published var isControllerConnected = false
    @Published var controllerName = ""
    
    // Input states for visualization
    @Published var leftTrigger: Float = 0.0
    @Published var rightTrigger: Float = 0.0
    @Published var leftShoulder = false
    @Published var rightShoulder = false
    @Published var dpadUp = false
    @Published var dpadDown = false
    @Published var dpadLeft = false
    @Published var dpadRight = false
    @Published var squareButton = false
    @Published var circleButton = false
    @Published var triangleButton = false
    
    private var controller: GCController?
    private var droneManager: DroneManager?
    private var lastR2Press: Date = Date.distantPast
    private var lastL2Press: Date = Date.distantPast
    private var lastR1Press: Date = Date.distantPast
    private var lastL1Press: Date = Date.distantPast
    
    // Debounce timing
    private let buttonDebounceInterval: TimeInterval = 0.3
    
    init() {
        setupControllerDetection()
    }
    
    private func setupControllerDetection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        
        // Check for already connected controllers
        if let controller = GCController.controllers().first {
            connectController(controller)
        }
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        connectController(controller)
    }
    
    @objc private func controllerDidDisconnect(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isControllerConnected = false
            self.controllerName = ""
            self.controller = nil
        }
    }
    
    private func connectController(_ controller: GCController) {
        self.controller = controller
        
        DispatchQueue.main.async {
            self.isControllerConnected = true
            self.controllerName = controller.vendorName ?? "Unknown Controller"
        }
        
        print("Controller connected: \(controller.vendorName ?? "Unknown")")
    }
    
    func setupControllerHandlers(droneManager: DroneManager) {
        self.droneManager = droneManager
        
        // Setup input handlers periodically to catch controller connections
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.setupInputHandlers()
        }
    }
    
    private func setupInputHandlers() {
        guard let controller = self.controller else { return }
        
        // Extended Gamepad (DualSense, Xbox)
        if let extendedGamepad = controller.extendedGamepad {
            setupExtendedGamepadHandlers(extendedGamepad)
        }
        // Micro Gamepad (Apple TV Remote, etc.)
        else if let microGamepad = controller.microGamepad {
            setupMicroGamepadHandlers(microGamepad)
        }
    }
    
    private func setupExtendedGamepadHandlers(_ gamepad: GCExtendedGamepad) {
        // Triggers - Altitude Control
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.rightTrigger = value
            }
            
            if pressed && self?.canProcessR2() == true {
                self?.handleR2Press()
            }
        }
        
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.leftTrigger = value
            }
            
            if pressed && self?.canProcessL2() == true {
                self?.handleL2Press()
            }
        }
        
        // Shoulder Buttons - Yaw Control
        gamepad.rightShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.rightShoulder = pressed
            }
            
            if pressed && self?.canProcessR1() == true {
                self?.handleR1Press()
            }
        }
        
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.leftShoulder = pressed
            }
            
            if pressed && self?.canProcessL1() == true {
                self?.handleL1Press()
            }
        }
        
        // D-Pad - Movement Control
        gamepad.dpad.up.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.dpadUp = pressed
            }
            if pressed {
                self?.droneManager?.moveForward(intensity: 40)
            }
        }
        
        gamepad.dpad.down.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.dpadDown = pressed
            }
            if pressed {
                self?.droneManager?.moveBackward(intensity: 40)
            }
        }
        
        gamepad.dpad.left.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.dpadLeft = pressed
            }
            if pressed {
                self?.droneManager?.moveLeft(intensity: 40)
            }
        }
        
        gamepad.dpad.right.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.dpadRight = pressed
            }
            if pressed {
                self?.droneManager?.moveRight(intensity: 40)
            }
        }
        
        // Face Buttons - Drone Control
        // Square (X on Xbox) - Arm
        gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.squareButton = pressed
            }
            if pressed {
                self?.droneManager?.armDrone()
            }
        }
        
        // Circle (B on Xbox) - Safe Disarm
        gamepad.buttonB.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.circleButton = pressed
            }
            if pressed {
                self?.droneManager?.safeDisarm()
            }
        }
        
        // Triangle (Y on Xbox) - Emergency Stop
        gamepad.buttonY.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.triangleButton = pressed
            }
            if pressed {
                self?.droneManager?.emergencyStop()
            }
        }
    }
    
    private func setupMicroGamepadHandlers(_ gamepad: GCMicroGamepad) {
        // Basic support for Apple TV remote or similar
        gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                self?.droneManager?.armDrone()
            }
        }
        
        gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                self?.droneManager?.safeDisarm()
            }
        }
    }
    
    // MARK: - Debouncing Logic
    
    private func canProcessR2() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastR2Press) > buttonDebounceInterval {
            lastR2Press = now
            return true
        }
        return false
    }
    
    private func canProcessL2() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastL2Press) > buttonDebounceInterval {
            lastL2Press = now
            return true
        }
        return false
    }
    
    private func canProcessR1() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastR1Press) > buttonDebounceInterval {
            lastR1Press = now
            return true
        }
        return false
    }
    
    private func canProcessL1() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastL1Press) > buttonDebounceInterval {
            lastL1Press = now
            return true
        }
        return false
    }
    
    // MARK: - Action Handlers
    
    private func handleR2Press() {
        print("R2 pressed - Altitude +10cm")
        droneManager?.adjustAltitude(by: 10)
    }
    
    private func handleL2Press() {
        print("L2 pressed - Altitude -10cm")
        droneManager?.adjustAltitude(by: -10)
    }
    
    private func handleR1Press() {
        print("R1 pressed - Yaw Right")
        droneManager?.yawRight(intensity: 90) // 90-degree turn
    }
    
    private func handleL1Press() {
        print("L1 pressed - Yaw Left")
        droneManager?.yawLeft(intensity: 90) // 90-degree turn
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}