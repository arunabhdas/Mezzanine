//
//  FlightPhysicsEngine.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//

import Foundation
import simd

class FlightPhysicsEngine {
    // Constants
    private let airDensity: Float = 1.225  // kg/m^3 at sea level
    private let gravity: Float = 9.81      // m/s^2
    
    // Aircraft parameters
    private let wingArea: Float            // m^2
    private let wingSpan: Float            // m
    private let aspectRatio: Float         // Wing aspect ratio
    private let ostwaldEfficiency: Float   // Efficiency factor
    
    // Aerodynamic coefficients
    private let cd0: Float                 // Zero-lift drag coefficient
    private let clSlope: Float             // Lift curve slope
    private let clMax: Float               // Maximum lift coefficient
    
    // Difficulty settings
    private var stabilityAssist: Float = 0.3  // 0.0 = No assist, 1.0 = Full assist
    
    init(aircraftType: AircraftType) {
        // Set aircraft-specific parameters
        switch aircraftType {
        case .lightPlane:
            wingArea = 16.0
            wingSpan = 10.0
            ostwaldEfficiency = 0.8
            cd0 = 0.027
            clSlope = 5.0
            clMax = 1.4
        case .jetFighter:
            wingArea = 25.0
            wingSpan = 12.0
            ostwaldEfficiency = 0.85
            cd0 = 0.022
            clSlope = 5.5
            clMax = 1.8
        case .heavyTransport:
            wingArea = 150.0
            wingSpan = 60.0
            ostwaldEfficiency = 0.75
            cd0 = 0.032
            clSlope = 4.8
            clMax = 1.3
        }
        
        // Calculate derived parameters
        aspectRatio = wingSpan * wingSpan / wingArea
    }
    
    func setDifficulty(_ difficulty: GameDifficulty) {
        switch difficulty {
        case .easy:
            stabilityAssist = 0.7
        case .normal:
            stabilityAssist = 0.3
        case .realistic:
            stabilityAssist = 0.0
        }
    }
    
    func updateAircraft(_ aircraft: inout Aircraft, deltaTime: Float, windVector: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) {
        // Calculate airspeed (considering wind)
        let airVelocity = aircraft.velocity - windVector
        let airspeed = length(airVelocity)
        
        // Skip physics if airspeed is too low (prevents NaN issues)
        guard airspeed > 0.1 else {
            // Apply gravity when airspeed is too low
            aircraft.acceleration = SIMD3<Float>(0, -gravity, 0)
            aircraft.velocity += aircraft.acceleration * deltaTime
            aircraft.position += aircraft.velocity * deltaTime
            return
        }
        
        // Calculate angle of attack
        let forwardVector = aircraft.rotation.act(SIMD3<Float>(0, 0, 1))
        let angleOfAttack = calculateAngleOfAttack(forwardVector: forwardVector, velocityVector: normalize(airVelocity))
        
        // Calculate aerodynamic forces
        let (lift, drag) = calculateAerodynamicForces(airspeed: airspeed, angleOfAttack: angleOfAttack)
        
        // Calculate thrust
        let thrust = calculateThrust(aircraft.throttle, forwardVector: forwardVector)
        
        // Apply gravity
        let weight = SIMD3<Float>(0, -aircraft.weight * gravity, 0)
        
        // Sum all forces
        let totalForce = lift + drag + thrust + weight
        
        // Calculate acceleration (F = ma)
        aircraft.acceleration = totalForce / aircraft.weight
        
        // Update velocity
        aircraft.velocity += aircraft.acceleration * deltaTime
        
        // Update position
        aircraft.position += aircraft.velocity * deltaTime
        
        // Calculate rotational forces and moments
        updateRotation(aircraft: &aircraft, deltaTime: deltaTime, airspeed: airspeed, angleOfAttack: angleOfAttack)
    }
    
    private func calculateAngleOfAttack(forwardVector: SIMD3<Float>, velocityVector: SIMD3<Float>) -> Float {
        // Angle between forward vector and velocity vector
        let dot = simd_dot(forwardVector, velocityVector)
        let angle = acos(clamp(dot, -1.0, 1.0))
        
        // Determine if angle is positive or negative based on lift direction
        let upVector = simd_cross(forwardVector, simd_cross(velocityVector, forwardVector))
        let direction = simd_dot(upVector, SIMD3<Float>(0, 1, 0)) > 0 ? 1.0 : -1.0
        
        return angle * Float(direction)
    }
    
    private func calculateAerodynamicForces(airspeed: Float, angleOfAttack: Float) -> (lift: SIMD3<Float>, drag: SIMD3<Float>) {
        // Dynamic pressure
        let q = 0.5 * airDensity * airspeed * airspeed
        
        // Lift coefficient (simplified)
        var cl = clSlope * angleOfAttack
        cl = clamp(cl, -clMax, clMax)  // Limit to max lift coefficient
        
        // Induced drag coefficient
        let cdi = (cl * cl) / (Float.pi * aspectRatio * ostwaldEfficiency)
        
        // Total drag coefficient
        let cd = cd0 + cdi
        
        // Calculate lift and drag magnitudes
        let liftMagnitude = q * wingArea * cl
        let dragMagnitude = q * wingArea * cd
        
        // Lift is perpendicular to airflow, drag is parallel to airflow
        let liftDirection = SIMD3<Float>(0, 1, 0)  // Simplified; should be perpendicular to velocity
        let dragDirection = SIMD3<Float>(0, 0, -1) // Simplified; should be opposite to velocity
        
        return (liftDirection * liftMagnitude, dragDirection * dragMagnitude)
    }
    
    private func calculateThrust(_ throttle: Float, forwardVector: SIMD3<Float>) -> SIMD3<Float> {
        // Simple linear thrust model
        let maxThrust: Float = 50000.0  // Newtons
        return forwardVector * (throttle * maxThrust)
    }
    
    private func updateRotation(aircraft: inout Aircraft, deltaTime: Float, airspeed: Float, angleOfAttack: Float) {
        // Control effectiveness increases with airspeed
        let controlEffectiveness = min(airspeed / 30.0, 1.0)
        
        // Roll rate proportional to aileron input
        let rollRate = aircraft.aileron * 2.0 * controlEffectiveness
        
        // Pitch rate proportional to elevator input and affected by angle of attack
        let pitchRate = aircraft.elevator * 1.0 * controlEffectiveness
        
        // Yaw rate proportional to rudder input
        let yawRate = aircraft.rudder * 1.0 * controlEffectiveness
        
        // Stability assistance - tends to level the aircraft when no inputs are given
        let stabilityRollCorrection = calculateStabilityCorrection(aircraft: aircraft, axis: SIMD3<Float>(0, 0, 1))
        let stabilityPitchCorrection = calculateStabilityCorrection(aircraft: aircraft, axis: SIMD3<Float>(1, 0, 0))
        
        // Combine stability assist with pilot inputs
        let adjustedRollRate = rollRate + stabilityRollCorrection * stabilityAssist * (1.0 - abs(aircraft.aileron))
        let adjustedPitchRate = pitchRate + stabilityPitchCorrection * stabilityAssist * (1.0 - abs(aircraft.elevator))
        
        // Create rotation quaternions
        let rollQuat = simd_quatf(angle: adjustedRollRate * deltaTime, axis: SIMD3<Float>(0, 0, 1))
        let pitchQuat = simd_quatf(angle: adjustedPitchRate * deltaTime, axis: SIMD3<Float>(1, 0, 0))
        let yawQuat = simd_quatf(angle: yawRate * deltaTime, axis: SIMD3<Float>(0, 1, 0))
        
        // Apply rotations (order matters!)
        aircraft.rotation = aircraft.rotation * rollQuat * pitchQuat * yawQuat
    }
    
    private func calculateStabilityCorrection(aircraft: Aircraft, axis: SIMD3<Float>) -> Float {
        // Get current up vector
        let upVector = aircraft.rotation.act(SIMD3<Float>(0, 1, 0))
        
        // Get right vector for roll correction
        let rightVector = aircraft.rotation.act(SIMD3<Float>(1, 0, 0))
        
        // For roll: Dot product of world up and aircraft right vector
        // For pitch: Dot product of world up and aircraft forward vector
        let dotProduct = axis.x != 0 ?
            simd_dot(rightVector, SIMD3<Float>(0, 1, 0)) :
            simd_dot(aircraft.rotation.act(SIMD3<Float>(0, 0, 1)), SIMD3<Float>(0, 0, 1))
        
        // Return a correction force proportional to the misalignment
        return -dotProduct * 2.0
    }
    
    private func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
        return Swift.min(Swift.max(value, min), max)
    }
}
