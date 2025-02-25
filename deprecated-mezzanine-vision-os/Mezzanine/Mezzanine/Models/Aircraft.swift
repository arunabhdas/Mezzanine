//
//  Aircraft.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//

import Foundation
import simd

struct Aircraft {
    // Physical properties
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var velocity: SIMD3<Float>
    var acceleration: SIMD3<Float>
    
    // Flight characteristics
    var thrust: Float
    var lift: Float
    var drag: Float
    var weight: Float
    
    // Control inputs (range -1.0 to 1.0)
    var throttle: Float  // 0.0 to 1.0
    var aileron: Float   // Roll control
    var elevator: Float  // Pitch control
    var rudder: Float    // Yaw control
    
    // Initialize with default values
    init(position: SIMD3<Float> = SIMD3<Float>(0, 100, 0),
         rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
         velocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
         acceleration: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
         thrust: Float = 0,
         lift: Float = 0,
         drag: Float = 0,
         weight: Float = 1000,
         throttle: Float = 0,
         aileron: Float = 0,
         elevator: Float = 0,
         rudder: Float = 0) {
        
        self.position = position
        self.rotation = rotation
        self.velocity = velocity
        self.acceleration = acceleration
        self.thrust = thrust
        self.lift = lift
        self.drag = drag
        self.weight = weight
        self.throttle = throttle
        self.aileron = aileron
        self.elevator = elevator
        self.rudder = rudder
    }
}
