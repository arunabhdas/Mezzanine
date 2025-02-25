//
//  MissionSystem.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//


import Foundation
import simd

class MissionSystem {
    // Current mission and progress
    private(set) var currentMission: Mission
    private(set) var currentCheckpointIndex: Int = 0
    
    // Mission metrics
    private var timeStarted: Date?
    private var timeCompleted: Date?
    private var checkpointTimes: [String: TimeInterval] = [:]
    private(set) var score: Int = 0
    
    // Events
    var onCheckpointReached: ((Checkpoint) -> Void)?
    var onMissionComplete: ((MissionProgress) -> Void)?
    var onMissionFailed: ((String) -> Void)?
    
    init(mission: Mission) {
        self.currentMission = mission
    }
    
    // Start the mission
    func startMission() {
        timeStarted = Date()
        currentCheckpointIndex = 0
        score = 0
        checkpointTimes.removeAll()
    }
    
    // Update mission progress based on aircraft position
    func updateProgress(aircraft: Aircraft) {
        guard timeStarted != nil, timeCompleted == nil else { return }
        
        // Check current time against time limit
        if let timeLimit = currentMission.timeLimit {
            let elapsedTime = Date().timeIntervalSince(timeStarted!)
            if elapsedTime > timeLimit {
                failMission(reason: "Time limit exceeded")
                return
            }
        }
        
        // Check if aircraft has reached the current checkpoint
        let currentCheckpoint = currentMission.checkpoints[currentCheckpointIndex]
        if currentCheckpoint.isAircraftInCheckpoint(aircraft: aircraft) {
            // Record time
            let elapsedTime = Date().timeIntervalSince(timeStarted!)
            checkpointTimes[currentCheckpoint.id] = elapsedTime
            
            // Award points
            let checkpointScore = calculateCheckpointScore(
                checkpoint: currentCheckpoint, 
                aircraft: aircraft,
                timeElapsed: elapsedTime
            )
            score += checkpointScore
            
            // Trigger callback
            onCheckpointReached?(currentCheckpoint)
            
            // Advance to next checkpoint
            currentCheckpointIndex += 1
            
            // Check if mission is complete
            if currentCheckpointIndex >= currentMission.checkpoints.count {
                completeMission()
            }
        }
    }
    
    // Check if all objectives are complete
    func isObjectiveComplete() -> Bool {
        return currentCheckpointIndex >= currentMission.checkpoints.count
    }
    
    // Mark mission as complete
    private func completeMission() {
        timeCompleted = Date()
        
        // Calculate final mission progress
        let progress = getMissionProgress()
        
        // Trigger callback
        onMissionComplete?(progress)
    }
    
    // Mark mission as failed
    private func failMission(reason: String) {
        timeCompleted = Date()
        
        // Trigger callback
        onMissionFailed?(reason)
    }
    
    // Calculate score for reaching a checkpoint
    private func calculateCheckpointScore(checkpoint: Checkpoint, aircraft: Aircraft, timeElapsed: TimeInterval) -> Int {
        var baseScore = 100
        
        // Bonus for speed
        let speed = length(aircraft.velocity)
        baseScore += Int(speed / 10)
        
        // Bonus for efficiency
        if let prevCheckpointTime = checkpointTimes[
            currentMission.checkpoints[max(0, currentCheckpointIndex - 1)].id
        ] {
            let timeTaken = timeElapsed - prevCheckpointTime
            baseScore += Int(max(0, 30 - timeTaken) * 10)
        }
        
        // Apply difficulty multiplier
        switch currentMission.difficulty {
        case .easy:
            return baseScore
        case .normal:
            return Int(Float(baseScore) * 1.5)
        case .realistic:
            return baseScore * 2
        }
    }
    
    // Get current mission progress
    func getMissionProgress() -> MissionProgress {
        let elapsedTime = timeCompleted?.timeIntervalSince(timeStarted ?? Date()) ?? 
                        Date().timeIntervalSince(timeStarted ?? Date())
        
        return MissionProgress(
            currentMissionID: currentMission.id,
            checkpointsCompleted: currentCheckpointIndex,
            totalCheckpoints: currentMission.checkpoints.count,
            score: score,
            timeElapsed: elapsedTime
        )
    }
}