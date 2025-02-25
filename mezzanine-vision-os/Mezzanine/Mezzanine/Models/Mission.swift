//
//  Mission.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//


import Foundation
import simd

struct Mission: Identifiable {
    var id: String
    var name: String
    var description: String
    var startPosition: SIMD3<Float>
    var startRotation: simd_quatf
    var checkpoints: [Checkpoint]
    var timeLimit: TimeInterval?  // Optional time limit
    var environmentSettings: EnvironmentConditions
    var requiredAircraftType: AircraftType?  // Optional aircraft requirement
    
    var difficulty: GameDifficulty
}

struct Checkpoint: Identifiable {
    var id: String
    var position: SIMD3<Float>
    var radius: Float  // How close aircraft must get to checkpoint
    var requiredAltitudeMin: Float?
    var requiredAltitudeMax: Float?
    var requiredSpeed: Float?  // Optional required speed
    var nextCheckpointDirection: SIMD3<Float>?  // Direction to next checkpoint (optional)
    
    // Check if aircraft is within this checkpoint
    func isAircraftInCheckpoint(aircraft: Aircraft) -> Bool {
        let distance = length(aircraft.position - position)
        
        // Check distance
        guard distance <= radius else { return false }
        
        // Check altitude constraints if they exist
        if let minAlt = requiredAltitudeMin, aircraft.position.y < minAlt {
            return false
        }
        
        if let maxAlt = requiredAltitudeMax, aircraft.position.y > maxAlt {
            return false
        }
        
        // Check speed constraint if it exists
        if let reqSpeed = requiredSpeed {
            let speed = length(aircraft.velocity)
            if abs(speed - reqSpeed) > reqSpeed * 0.1 { // Within 10% of required speed
                return false
            }
        }
        
        return true
    }
}