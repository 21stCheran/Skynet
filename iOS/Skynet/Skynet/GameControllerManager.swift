//
//  GameControllerManager.swift
//  Skynet
//

import Foundation
import Combine
#if canImport(GameController)
import GameController
#endif

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
    
    private var droneManager: DroneManager?
    private var lastR2TriggerState: Float = 0.0
    private var lastL2TriggerState: Float = 0.0
    private let triggerThreshold: Float = 0.7
    
    init() {
        #if canImport(GameController)
        setupControllerDiscovery()
        #else
        print("GameController support not available")
        #endif
    }
    
    #if canImport(GameController)
    private func setupControllerDiscovery() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        
        GCController.startWirelessControllerDiscovery {
            print("Controller discovery completed")
        }
        
        // Check for already connected controllers
        if let controller = GCController.controllers().first {
            setupController(controller)
        }
    }
    
    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        DispatchQueue.main.async {
            self.setupController(controller)
        }
    }
    
    @objc private func controllerDisconnected(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isControllerConnected = false
            self.controllerName = ""
        }
    }
    
    private func setupController(_ controller: GCController) {
        isControllerConnected = true
        controllerName = controller.vendorName ?? "Unknown Controller"
        
        guard let gamepad = controller.extendedGamepad else { return }
        
        // Setup trigger handlers for throttle control
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (trigger, value, pressed) in
            DispatchQueue.main.async {
                self?.rightTrigger = value
                self?.handleR2TriggerChange(value)
            }
        }
        
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (trigger, value, pressed) in
            DispatchQueue.main.async {
                self?.leftTrigger = value
                self?.handleL2TriggerChange(value)
            }
        }
        
        // Shoulder buttons for movement
        gamepad.rightShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.rightShoulder = pressed
                if pressed {
                    self?.droneManager?.yawRight(intensity: 45)
                }
            }
        }
        
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.leftShoulder = pressed
                if pressed {
                    self?.droneManager?.yawLeft(intensity: 45)
                }
            }
        }
        
        // D-Pad for movement
        gamepad.dpad.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            DispatchQueue.main.async {
                self?.dpadUp = yValue > 0.5
                self?.dpadDown = yValue < -0.5
                self?.dpadLeft = xValue < -0.5
                self?.dpadRight = xValue > 0.5
                
                let intensity = 40
                
                if yValue > 0.5 {
                    self?.droneManager?.moveForward(intensity: intensity)
                } else if yValue < -0.5 {
                    self?.droneManager?.moveBackward(intensity: intensity)
                }
                
                if xValue < -0.5 {
                    self?.droneManager?.moveLeft(intensity: intensity)
                } else if xValue > 0.5 {
                    self?.droneManager?.moveRight(intensity: intensity)
                }
            }
        }
        
        // Face buttons
        gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.squareButton = pressed
                if pressed {
                    self?.droneManager?.armDrone()
                }
            }
        }
        
        gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.circleButton = pressed
                if pressed {
                    self?.droneManager?.safeDisarm()
                }
            }
        }
        
        gamepad.buttonY.valueChangedHandler = { [weak self] (button, value, pressed) in
            DispatchQueue.main.async {
                self?.triangleButton = pressed
                if pressed {
                    self?.droneManager?.emergencyStop()
                }
            }
        }
    }
    
    private func handleR2TriggerChange(_ value: Float) {
        // R2 increases throttle by 5% when pressed above threshold
        if value > triggerThreshold && lastR2TriggerState <= triggerThreshold {
            droneManager?.adjustThrottlePercentage(by: 5)
        }
        lastR2TriggerState = value
    }
    
    private func handleL2TriggerChange(_ value: Float) {
        // L2 decreases throttle by 5% when pressed above threshold
        if value > triggerThreshold && lastL2TriggerState <= triggerThreshold {
            droneManager?.adjustThrottlePercentage(by: -5)
        }
        lastL2TriggerState = value
    }
    #endif
    
    func setupControllerHandlers(droneManager: DroneManager) {
        self.droneManager = droneManager
    }
    
    deinit {
        #if canImport(GameController)
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
        #endif
    }
}