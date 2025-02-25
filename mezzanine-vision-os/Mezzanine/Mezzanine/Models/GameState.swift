//
//  GameState.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//

import Foundation
import simd

enum GameState {
    case menu
    case briefing
    case playing
    case paused
    case gameOver
    case missionComplete
}

struct MissionProgress {
    var currentMissionID: String
    var checkpointsCompleted: Int
    var totalCheckpoints: Int
    var score: Int
    var timeElapsed: TimeInterval
    
    var percentComplete: Float {
        return Float(checkpointsCompleted) / Float(totalCheckpoints)
    }
}

struct EnvironmentConditions {
    var windDirection: SIMD3<Float>  // Direction vector
    var windSpeed: Float             // m/s
    var turbulence: Float            // 0-1 scale
    var visibility: Float            // meters
    var timeOfDay: Float             // 0-24 hours
    
    // Derived wind vector
    var windVector: SIMD3<Float> {
        return normalize(windDirection) * windSpeed
    }
}

enum AircraftType {
    case lightPlane
    case jetFighter
    case heavyTransport
}

enum GameDifficulty {
    case easy
    case normal
    case realistic
}
