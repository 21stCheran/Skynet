//
//  GameControllerManager.swift
//  Skynet
//

import Foundation
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
    
    private var droneManager: DroneManager?
    
    init() {
        // GameController support disabled for compatibility
        print("GameController support not available")
    }
    
    func setupControllerHandlers(droneManager: DroneManager) {
        self.droneManager = droneManager
        // Controller support disabled for compatibility
    }
    
    deinit {
        // No cleanup needed
    }
}