//
//  FlightViewModel.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//
import Foundation
import Observation
import RealityKit

@Observable class FlightViewModel {
    // State for UI updates
    var aircraft: Aircraft
    var gameState: GameState = .menu
    var missionProgress: MissionProgress
    var environmentConditions: EnvironmentConditions
    
    // User input values
    var throttleInput: Float = 0.0 // 0.0 to 1.0
    var aileronInput: Float = 0.0  // -1.0 to 1.0 (left to right)
    var elevatorInput: Float = 0.0 // -1.0 to 1.0 (down to up)
    var rudderInput: Float = 0.0   // -1.0 to 1.0 (left to right)
    
    // Flight information for HUD
    var altitude: Float = 0.0      // Meters above sea level
    var airspeed: Float = 0.0      // Meters per second
    var verticalSpeed: Float = 0.0 // Meters per second
    var heading: Float = 0.0       // Degrees (0-360)
    var roll: Float = 0.0          // Degrees (-180 to 180)
    var pitch: Float = 0.0         // Degrees (-90 to 90)
    
    // Game world
    var worldEntity: Entity?
    
    // Game engine components
    private var physicsEngine: FlightPhysicsEngine
    private var worldGenerator: WorldGenerator
    private var missionSystem: MissionSystem
    
    // Game loop
    private var timer: Timer?
    private var lastUpdateTime: Date?
    private var frameCount: Int = 0
    private var frameTimeTotal: TimeInterval = 0
    var fps: Double = 0.0
    
    // Input smoothing
    private var inputSmoothingFactor: Float = 0.2
    
    init(aircraftType: AircraftType = .lightPlane, mission: Mission? = nil) {
        // Initialize with default aircraft
        self.aircraft = Aircraft(weight: aircraftType == .heavyTransport ? 50000 :
                                        (aircraftType == .jetFighter ? 15000 : 1200))
        
        // Initialize with default mission if none provided
        let defaultMission = mission ?? Mission(
            id: "training",
            name: "Training Flight",
            description: "A simple training flight to get familiar with the controls.",
            startPosition: SIMD3<Float>(0, 100, 0),
            startRotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            checkpoints: [],
            timeLimit: nil,
            environmentSettings: EnvironmentConditions(
                windDirection: SIMD3<Float>(1, 0, 0),
                windSpeed: 2.0,
                turbulence: 0.1,
                visibility: 10000,
                timeOfDay: 12.0
            ),
            difficulty: .normal
        )
        
        // Initialize progress with default mission
        self.missionProgress = MissionProgress(
            currentMissionID: defaultMission.id,
            checkpointsCompleted: 0,
            totalCheckpoints: defaultMission.checkpoints.count,
            score: 0,
            timeElapsed: 0
        )
        
        // Initialize environment from mission
        self.environmentConditions = defaultMission.environmentSettings
        
        // Initialize game systems
        self.physicsEngine = FlightPhysicsEngine(aircraftType: aircraftType)
        self.worldGenerator = WorldGenerator()
        self.missionSystem = MissionSystem(mission: defaultMission)
        
        // Set up mission callbacks
        setupMissionCallbacks()
    }
    
    private func setupMissionCallbacks() {
        missionSystem.onCheckpointReached = { [weak self] checkpoint in
            // Handle checkpoint reached
            // Maybe play sound, show notification, etc.
        }
        
        missionSystem.onMissionComplete = { [weak self] progress in
            guard let self = self else { return }
            // Update mission progress
            self.missionProgress = progress
            // Change game state
            self.gameState = .missionComplete
            // Stop the game loop
            self.pauseGame()
        }
        
        missionSystem.onMissionFailed = { [weak self] reason in
            guard let self = self else { return }
            // Change game state
            self.gameState = .gameOver
            // Stop the game loop
            self.pauseGame()
        }
    }
    
    // Apply smoothing to control inputs during simulation update
    private func applyInputSmoothing() {
        // Apply smoothing for all controls
        aircraft.throttle += (throttleInput - aircraft.throttle) * inputSmoothingFactor
        aircraft.aileron += (aileronInput - aircraft.aileron) * inputSmoothingFactor
        aircraft.elevator += (elevatorInput - aircraft.elevator) * inputSmoothingFactor
        aircraft.rudder += (rudderInput - aircraft.rudder) * inputSmoothingFactor
    }
    
    // Start the game
    func startGame(mission: Mission? = nil) {
        // Reset aircraft state if mission provided
        if let mission = mission {
            aircraft.position = mission.startPosition
            aircraft.rotation = mission.startRotation
            aircraft.velocity = SIMD3<Float>(0, 0, 0)
            aircraft.acceleration = SIMD3<Float>(0, 0, 0)
            
            // Reset mission system
            missionSystem = MissionSystem(mission: mission)
            setupMissionCallbacks()
            
            // Set environmental conditions from mission
            environmentConditions = mission.environmentSettings
            
            // Generate world
            worldEntity = worldGenerator.generateWorld(environmentConditions: environmentConditions)
        }
        
        // Start mission tracking
        missionSystem.startMission()
        
        // Change game state
        gameState = .playing
        
        // Start game loop
        startGameLoop()
    }
    
    // Pause the game
    func pauseGame() {
        // Stop the game loop
        stopGameLoop()
        
        // Change game state if currently playing
        if gameState == .playing {
            gameState = .paused
        }
    }
    
    // Resume the game
    func resumeGame() {
        // Only resume if currently paused
        if gameState == .paused {
            gameState = .playing
            startGameLoop()
        }
    }
    
    // Start the game loop timer
    func startGameLoop() {
        lastUpdateTime = Date()
        frameCount = 0
        frameTimeTotal = 0
        
        // Create a timer that fires 60 times per second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateSimulation()
        }
    }
    
    // Stop the game loop timer
    private func stopGameLoop() {
        timer?.invalidate()
        timer = nil
        lastUpdateTime = nil
    }
    
    // Update the simulation
    private func updateSimulation() {
        guard gameState == .playing else { return }
        
        // Calculate delta time
        let currentTime = Date()
        guard let lastTime = lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime.timeIntervalSince(lastTime)
        lastUpdateTime = currentTime
        
        // Update FPS calculation
        frameCount += 1
        frameTimeTotal += deltaTime
        if frameTimeTotal >= 1.0 {
            fps = Double(frameCount) / frameTimeTotal
            frameCount = 0
            frameTimeTotal = 0
        }
        
        // Apply input smoothing
        applyInputSmoothing()
        
        // Update physics
        physicsEngine.updateAircraft(
            &aircraft,
            deltaTime: Float(deltaTime),
            windVector: environmentConditions.windVector
        )
        
        // Update mission progress
        missionSystem.updateProgress(aircraft: aircraft)
        
        // Update missionProgress property
        missionProgress = missionSystem.getMissionProgress()
        
        // Update flight information for HUD
        updateFlightInfo()
    }
    
    // Update flight information for HUD
    private func updateFlightInfo() {
        // Calculate altitude (y-coordinate is height)
        altitude = aircraft.position.y
        
        // Calculate airspeed (magnitude of velocity vector)
        airspeed = length(aircraft.velocity)
        
        // Calculate vertical speed (y component of velocity)
        verticalSpeed = aircraft.velocity.y
        
        // Calculate heading from forward vector
        let forwardVector = aircraft.rotation.act(SIMD3<Float>(0, 0, 1))
        heading = atan2(forwardVector.x, forwardVector.z) * (180 / Float.pi)
        if heading < 0 {
            heading += 360
        }
        
        // Calculate roll from up vector
        let upVector = aircraft.rotation.act(SIMD3<Float>(0, 1, 0))
        roll = atan2(upVector.x, upVector.y) * (180 / Float.pi)
        
        // Calculate pitch from forward vector
        pitch = asin(forwardVector.y) * (180 / Float.pi)
    }
}
