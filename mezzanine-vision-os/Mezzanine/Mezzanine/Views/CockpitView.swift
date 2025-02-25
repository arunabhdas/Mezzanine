//
//  CockpitView.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//
import SwiftUI
import RealityKit
import simd

struct CockpitView: View {
    var viewModel: FlightViewModel
    var onReturnToMenu: () -> Void
    
    // State for gesture inputs
    @State private var throttleGestureValue: Float = 0.0
    @State private var stickGestureOffset: CGSize = .zero
    @State private var rudderGestureValue: Float = 0.0
    
    var body: some View {
        ZStack {
            // 3D Flight view using RealityKit
            FlightSceneView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Cockpit UI overlay
            VStack {
                // Top HUD
                FlightInstrumentsView(
                    altitude: viewModel.altitude,
                    airspeed: viewModel.airspeed,
                    verticalSpeed: viewModel.verticalSpeed,
                    heading: viewModel.heading,
                    roll: viewModel.roll,
                    pitch: viewModel.pitch,
                    fps: viewModel.fps
                )
                
                Spacer()
                
                // Bottom controls
                HStack {
                    // Throttle control
                    ThrottleControlView(value: $throttleGestureValue)
                        .onChange(of: throttleGestureValue) { newValue in
                            viewModel.throttleInput = newValue
                        }
                    
                    Spacer()
                    
                    // Control stick
                    FlightStickView(offset: $stickGestureOffset)
                        .onChange(of: stickGestureOffset) { newValue in
                            // Convert from gesture space (-1 to 1 in both axes)
                            let maxOffset: CGFloat = 100
                            let normalizedX = Float(newValue.width / maxOffset)
                            let normalizedY = Float(newValue.height / maxOffset)
                            
                            // Update view model with clamped values
                            viewModel.aileronInput = min(max(normalizedX, -1.0), 1.0)
                            viewModel.elevatorInput = min(max(-normalizedY, -1.0), 1.0)
                        }
                    
                    Spacer()
                    
                    // Rudder control
                    RudderControlView(value: $rudderGestureValue)
                        .onChange(of: rudderGestureValue) { newValue in
                            viewModel.rudderInput = newValue
                        }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            
            // Game state overlays
            if viewModel.gameState == .paused {
                PauseMenuView(viewModel: viewModel, onReturnToMenu: onReturnToMenu)
            } else if viewModel.gameState == .gameOver {
                GameOverView(viewModel: viewModel, onReturnToMenu: onReturnToMenu)
            } else if viewModel.gameState == .missionComplete {
                MissionCompleteView(viewModel: viewModel, onReturnToMenu: onReturnToMenu)
            }
        }
        .onAppear {
            // Initial setup when view appears
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        // Set initial gesture values from view model
        throttleGestureValue = viewModel.throttleInput
        stickGestureOffset = CGSize(
            width: CGFloat(viewModel.aileronInput * 100),
            height: CGFloat(-viewModel.elevatorInput * 100)
        )
        rudderGestureValue = viewModel.rudderInput
    }
}

// Custom RealityKit view for 3D flight scene
struct FlightSceneView: View {
    var viewModel: FlightViewModel
    @State private var flyingObjects: [FlyingObject] = []
    @State private var lastUpdateTime: Date = Date()
    
    // Timer for updating flying objects
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        RealityView { content in
            // Create root entity
            let rootEntity = Entity()
            
            // Add the world entity if available
            if let worldEntity = viewModel.worldEntity {
                rootEntity.addChild(worldEntity)
            } else {
                // Add a default terrain if no world is available
                rootEntity.addChild(createDefaultTerrain())
            }
            
            // Add aircraft entity
            let aircraftEntity = createAircraftEntity()
            aircraftEntity.position = viewModel.aircraft.position
            aircraftEntity.orientation = viewModel.aircraft.rotation
            rootEntity.addChild(aircraftEntity)
            
            // Add sky entity
            rootEntity.addChild(createSkyEntity())
            
            // Add dynamic flying objects container
            let flyingObjectsEntity = Entity()
            flyingObjectsEntity.name = "flyingObjects"
            rootEntity.addChild(flyingObjectsEntity)
            
            // Add ground objects for reference
            rootEntity.addChild(createGroundObjects())
            
            // Add lighting
            addLighting(to: rootEntity)
            
            // Add the root entity to the scene
            content.add(rootEntity)
        } update: { content in
            // Find the aircraft entity
            if let aircraft = content.entities.first?.children.first(where: { $0.name == "aircraft" }) {
                // Update position and rotation
                aircraft.position = viewModel.aircraft.position
                aircraft.orientation = viewModel.aircraft.rotation
                
                // Update flying objects
                updateFlyingObjects(in: content, aircraftPosition: viewModel.aircraft.position, aircraftVelocity: viewModel.aircraft.velocity)
            }
        }
        .onAppear {
            // Begin simulation if not already started
            if viewModel.gameState != .playing {
                viewModel.gameState = .playing
                viewModel.startGameLoop()
            }
            
            // Initialize flying objects
            initializeFlyingObjects()
        }
        .onDisappear {
            // Clean up resources
            flyingObjects.removeAll()
        }
        .onReceive(timer) { _ in
            // Update tracking of flying objects and occasionally add new ones
            let currentTime = Date()
            let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
            lastUpdateTime = currentTime
            
            // Update flying objects positions based on aircraft velocity
            for i in 0..<flyingObjects.count {
                var object = flyingObjects[i]
                
                // Move objects backward relative to aircraft velocity
                let relativeVelocity = -viewModel.aircraft.velocity * Float(deltaTime) * 0.5
                object.position += relativeVelocity
                
                // Check if object is too far behind and should be reset
                let distanceToAircraft = distance(object.position, viewModel.aircraft.position)
                if distanceToAircraft > 2000 || distanceToAircraft < 10 {
                    // Reset object to a new position ahead of the aircraft
                    object.position = generateNewFlyingObjectPosition(
                        aircraftPosition: viewModel.aircraft.position,
                        aircraftForward: viewModel.aircraft.rotation.act(SIMD3<Float>(0, 0, 1))
                    )
                }
                
                flyingObjects[i] = object
            }
            
            // Occasionally add new objects
            if Float.random(in: 0...1) < 0.05 { // 5% chance per timer tick
                addNewFlyingObject()
            }
        }
    }
    
    // Update flying objects in the scene
    private func updateFlyingObjects(in content: RealityViewContent, aircraftPosition: SIMD3<Float>, aircraftVelocity: SIMD3<Float>) {
        guard let flyingObjectsEntity = content.entities.first?.children.first(where: { $0.name == "flyingObjects" }) else {
            return
        }
        
        // Instead of removing and recreating all entities each time,
        // update existing entities or add new ones as needed
        
        // First, create a map of existing entities by ID
        var existingEntities = [String: Entity]()
        for child in flyingObjectsEntity.children {
            existingEntities[child.name] = child
        }
        
        // Now update or create entities
        for object in flyingObjects {
            if let existingEntity = existingEntities[object.id] {
                // Update existing entity's position and orientation
                existingEntity.position = object.position
                existingEntity.orientation = object.rotation
                
                // Remove from the map to track which ones we've processed
                existingEntities.removeValue(forKey: object.id)
            } else {
                // Create a new entity for this object
                let entity = generateFlyingObjectEntity(object)
                flyingObjectsEntity.addChild(entity)
            }
        }
        
        // Remove any entities that don't have corresponding flying objects
        // Use a temporary array to avoid modifying while iterating
        for (id, entity) in existingEntities {
            // Only remove if it's not one of our special entities
            if id != "terrain" && id != "sky" && id != "aircraft" {
                entity.removeFromParent()
            }
        }
    }
    
    // Initialize flying objects array
    private func initializeFlyingObjects() {
        flyingObjects = []
        
        // Add initial flying objects (fewer for stability)
        for _ in 0..<15 {
            addNewFlyingObject()
        }
    }
    
    // Add a new flying object
    private func addNewFlyingObject() {
        guard flyingObjects.count < 100 else { return } // Limit the number of objects
        
        // Get forward vector with safety checks
        var forwardVector = viewModel.aircraft.rotation.act(SIMD3<Float>(0, 0, 1))
        if forwardVector.x.isNaN || forwardVector.y.isNaN || forwardVector.z.isNaN {
            forwardVector = SIMD3<Float>(0, 0, 1) // Default to forward if NaN
        }
        
        // Get position with safety checks
        let position = generateNewFlyingObjectPosition(
            aircraftPosition: validateVector3(viewModel.aircraft.position, defaultValue: SIMD3<Float>(0, 100, 0)),
            aircraftForward: forwardVector
        )
        
        // Create scale with safety checks
        let scale = SIMD3<Float>(
            clamp(Float.random(in: 0.5...2.0), 0.1, 10.0),
            clamp(Float.random(in: 0.5...2.0), 0.1, 10.0),
            clamp(Float.random(in: 0.5...2.0), 0.1, 10.0)
        )
        
        // Create rotation with safety checks
        let angle = clamp(Float.random(in: 0...Float.pi*2), 0, Float.pi*2)
        let axis = validateVector(SIMD3<Float>(0, 1, 0), defaultValue: SIMD3<Float>(0, 1, 0))
        let rotation = simd_quatf(angle: angle, axis: axis)
        
        let objectType: FlyingObjectType
        let random = Float.random(in: 0...1)
        if random < 0.7 {
            objectType = .cloud
        } else if random < 0.9 {
            objectType = .bird
        } else {
            objectType = .aircraft
        }
        
        let newObject = FlyingObject(
            id: UUID().uuidString,
            type: objectType,
            position: position,
            scale: scale,
            rotation: rotation
        )
        
        flyingObjects.append(newObject)
    }
    
    // Helper to validate SIMD3 and ensure it doesn't contain NaN
    private func validateVector3(_ vector: SIMD3<Float>, defaultValue: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            vector.x.isNaN ? defaultValue.x : vector.x,
            vector.y.isNaN ? defaultValue.y : vector.y,
            vector.z.isNaN ? defaultValue.z : vector.z
        )
    }
    
    // Helper to clamp a value between min and max
    private func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
        return Swift.min(Swift.max(value, min), max)
    }
    
    // Generate position for a new flying object
    private func generateNewFlyingObjectPosition(aircraftPosition: SIMD3<Float>, aircraftForward: SIMD3<Float>) -> SIMD3<Float> {
        let distance = Float.random(in: 200...1500)
        let horizontalAngle = Float.random(in: -Float.pi/2...Float.pi/2) // ±90° from forward
        let verticalAngle = Float.random(in: -Float.pi/4...Float.pi/4) // ±45° up/down
        
        // Safety check for zero-length forward vector
        guard length(aircraftForward) > 0.001 else {
            // Fallback to default direction if forward vector is invalid
            return aircraftPosition + SIMD3<Float>(0, 0, distance)
        }
        
        // Calculate direction vector
        let forwardNormalized = normalize(aircraftForward)
        // Ensure we have a valid normalized vector
        guard !forwardNormalized.x.isNaN && !forwardNormalized.y.isNaN && !forwardNormalized.z.isNaN else {
            return aircraftPosition + SIMD3<Float>(0, 0, distance)
        }
        
        let forwardRotated = simd_quatf(angle: horizontalAngle, axis: SIMD3<Float>(0, 1, 0)).act(forwardNormalized)
        let direction = simd_quatf(angle: verticalAngle, axis: SIMD3<Float>(1, 0, 0)).act(forwardRotated)
        
        // Final safety check on the resulting direction
        let safeDirection = validateVector(direction, defaultValue: SIMD3<Float>(0, 0, 1))
        
        // Generate position ahead of aircraft
        return aircraftPosition + safeDirection * distance
    }
    
    // Helper to validate a vector and ensure it doesn't contain NaN values
    private func validateVector(_ vector: SIMD3<Float>, defaultValue: SIMD3<Float>) -> SIMD3<Float> {
        if vector.x.isNaN || vector.y.isNaN || vector.z.isNaN || length(vector) < 0.001 {
            return defaultValue
        }
        
        // Normalize if needed, with safety
        if abs(length(vector) - 1.0) > 0.001 {
            let len = length(vector)
            if len > 0.001 {
                return vector / len
            } else {
                return defaultValue
            }
        }
        
        return vector
    }
    
    // Create entity for a flying object based on its type
    private func generateFlyingObjectEntity(_ object: FlyingObject) -> Entity {
        let entity = Entity()
        entity.name = object.id
        
        // Safety check for NaN values in position and scale
        let safePosition = SIMD3<Float>(
            object.position.x.isNaN ? 0 : object.position.x,
            object.position.y.isNaN ? 0 : object.position.y,
            object.position.z.isNaN ? 0 : object.position.z
        )
        
        let safeScale = SIMD3<Float>(
            object.scale.x.isNaN || object.scale.x <= 0 ? 1 : object.scale.x,
            object.scale.y.isNaN || object.scale.y <= 0 ? 1 : object.scale.y,
            object.scale.z.isNaN || object.scale.z <= 0 ? 1 : object.scale.z
        )
        
        // Safety check for NaN in rotation quaternion
        let safeRotation = validateQuaternion(object.rotation)
        
        entity.position = safePosition
        entity.scale = safeScale
        entity.orientation = safeRotation
        
        // Create mesh based on object type
        var mesh: MeshResource
        var material: SimpleMaterial
        
        switch object.type {
        case .cloud:
            // Simple cloud shape
            mesh = .generateBox(width: 50, height: 30, depth: 50)
            material = SimpleMaterial(color: .white.withAlphaComponent(0.8), roughness: 1.0, isMetallic: false)
            
        case .bird:
            // Simple bird shape
            mesh = .generateBox(width: 3, height: 1, depth: 5)
            material = SimpleMaterial(color: .black, roughness: 0.5, isMetallic: false)
            
        case .aircraft:
            // Simple aircraft shape
            mesh = .generateBox(width: 20, height: 5, depth: 25)
            material = SimpleMaterial(color: .gray, roughness: 0.3, isMetallic: true)
        }
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        entity.addChild(modelEntity)
        
        return entity
    }
    
    // Validate quaternion to ensure it's not NaN or zero
    private func validateQuaternion(_ q: simd_quatf) -> simd_quatf {
        if q.vector.x.isNaN || q.vector.y.isNaN || q.vector.z.isNaN || q.vector.w.isNaN ||
           (abs(q.vector.x) < 0.00001 && abs(q.vector.y) < 0.00001 &&
            abs(q.vector.z) < 0.00001 && abs(q.vector.w) < 0.00001) {
            // Return identity quaternion if invalid
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        
        // Normalize the quaternion if it's not already
        let length = sqrt(q.vector.x*q.vector.x + q.vector.y*q.vector.y +
                          q.vector.z*q.vector.z + q.vector.w*q.vector.w)
        
        if abs(length - 1.0) > 0.001 && length > 0.00001 {
            // Normalize only if length is not too close to zero
            return simd_quatf(
                ix: q.vector.x / length,
                iy: q.vector.y / length,
                iz: q.vector.z / length,
                r: q.vector.w / length
            )
        }
        
        return q
    }
    
    private func createAircraftEntity() -> Entity {
        let aircraft = Entity()
        aircraft.name = "aircraft"
        
        // Create a more detailed aircraft model
        let fuselage = ModelEntity(
            mesh: .generateBox(width: 0.5, height: 0.5, depth: 4),
            materials: [SimpleMaterial(color: .blue, roughness: 0.2, isMetallic: true)]
        )
        aircraft.addChild(fuselage)
        
        // Wings
        let leftWing = ModelEntity(
            mesh: .generateBox(width: 6, height: 0.1, depth: 1.5),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)]
        )
        leftWing.position = SIMD3<Float>(-3, 0, 0)
        aircraft.addChild(leftWing)
        
        let rightWing = ModelEntity(
            mesh: .generateBox(width: 6, height: 0.1, depth: 1.5),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)]
        )
        rightWing.position = SIMD3<Float>(3, 0, 0)
        aircraft.addChild(rightWing)
        
        // Tail
        let tailFin = ModelEntity(
            mesh: .generateBox(width: 0.1, height: 1.2, depth: 1),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)]
        )
        tailFin.position = SIMD3<Float>(0, 0.6, -1.8)
        aircraft.addChild(tailFin)
        
        // Horizontal stabilizers
        let leftStab = ModelEntity(
            mesh: .generateBox(width: 1.5, height: 0.1, depth: 0.8),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)]
        )
        leftStab.position = SIMD3<Float>(-0.8, 0, -1.8)
        aircraft.addChild(leftStab)
        
        let rightStab = ModelEntity(
            mesh: .generateBox(width: 1.5, height: 0.1, depth: 0.8),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)]
        )
        rightStab.position = SIMD3<Float>(0.8, 0, -1.8)
        aircraft.addChild(rightStab)
        
        // Cockpit (glass)
        let cockpit = ModelEntity(
            mesh: .generateBox(width: 0.4, height: 0.4, depth: 0.8),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.6), roughness: 0.0, isMetallic: false)]
        )
        cockpit.position = SIMD3<Float>(0, 0.3, 1.2)
        aircraft.addChild(cockpit)
        
        // Scale the entire aircraft
        aircraft.scale = SIMD3<Float>(5, 5, 5)
        
        return aircraft
    }
    
    private func createDefaultTerrain() -> Entity {
        let terrain = Entity()
        terrain.name = "terrain"
        
        // Create a large ground plane
        let groundMesh = MeshResource.generatePlane(width: 10000, depth: 10000)
        let groundMaterial = SimpleMaterial(color: .green, roughness: 0.8, isMetallic: false)
        let groundEntity = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        groundEntity.position = SIMD3<Float>(0, -100, 0)
        
        // Add collision component to the ground
        groundEntity.collision = CollisionComponent(shapes: [.generateBox(width: 10000, height: 1, depth: 10000)])
        
        terrain.addChild(groundEntity)
        
        // Add some mountains in the distance
        for i in 0..<10 {
            let mountainHeight = Float.random(in: 200...800)
            let mountainWidth = Float.random(in: 300...600)
            
            let mountainMesh = MeshResource.generateBox(width: mountainWidth, height: mountainHeight, depth: mountainWidth)
            let mountainMaterial = SimpleMaterial(color: .brown, roughness: 0.9, isMetallic: false)
            let mountainEntity = ModelEntity(mesh: mountainMesh, materials: [mountainMaterial])
            
            // Position mountains randomly in a circle around the center
            let angle = Float(i) * (2 * .pi / 10)
            let distance: Float = 3000
            mountainEntity.position = SIMD3<Float>(
                cos(angle) * distance,
                -100 + (mountainHeight / 2),
                sin(angle) * distance
            )
            
            terrain.addChild(mountainEntity)
        }
        
        return terrain
    }
    
    private func createGroundObjects() -> Entity {
        let groundObjects = Entity()
        groundObjects.name = "groundObjects"
        
        // Add trees, buildings, and other ground objects
        for i in 0..<200 {
            let isTree = Float.random(in: 0...1) < 0.7
            let objectEntity = Entity()
            
            if isTree {
                // Create a tree
                let trunkHeight = Float.random(in: 10...30)
                let trunkWidth = trunkHeight / 10
                
                // Trunk
                let trunkMesh = MeshResource.generateBox(width: trunkWidth, height: trunkHeight, depth: trunkWidth)
                let trunkMaterial = SimpleMaterial(color: .brown, roughness: 0.9, isMetallic: false)
                let trunkEntity = ModelEntity(mesh: trunkMesh, materials: [trunkMaterial])
                trunkEntity.position = SIMD3<Float>(0, trunkHeight/2, 0)
                objectEntity.addChild(trunkEntity)
                
                // Foliage
                let foliageWidth = Float.random(in: 3...6) * trunkWidth
                let foliageMesh = MeshResource.generateSphere(radius: foliageWidth)
                let foliageMaterial = SimpleMaterial(color: .green, roughness: 1.0, isMetallic: false)
                let foliageEntity = ModelEntity(mesh: foliageMesh, materials: [foliageMaterial])
                foliageEntity.position = SIMD3<Float>(0, trunkHeight, 0)
                objectEntity.addChild(foliageEntity)
            } else {
                // Create a building
                let buildingHeight = Float.random(in: 20...100)
                let buildingWidth = Float.random(in: 10...50)
                let buildingDepth = Float.random(in: 10...50)
                
                let buildingMesh = MeshResource.generateBox(width: buildingWidth, height: buildingHeight, depth: buildingDepth)
                let buildingMaterial = SimpleMaterial(color: .gray, roughness: 0.7, isMetallic: false)
                let buildingEntity = ModelEntity(mesh: buildingMesh, materials: [buildingMaterial])
                buildingEntity.position = SIMD3<Float>(0, buildingHeight/2, 0)
                objectEntity.addChild(buildingEntity)
            }
            
            // Position randomly around the terrain
            let radius = Float.random(in: 500...4000)
            let angle = Float.random(in: 0...(2 * .pi))
            objectEntity.position = SIMD3<Float>(
                cos(angle) * radius,
                -100, // Ground level
                sin(angle) * radius
            )
            
            groundObjects.addChild(objectEntity)
        }
        
        return groundObjects
    }
    
    private func createSkyEntity() -> Entity {
        let sky = Entity()
        sky.name = "sky"
        
        // Add a skybox (simplified for this example)
        let skyboxSize: Float = 20000
        let skyboxMesh = MeshResource.generateBox(width: skyboxSize, height: skyboxSize, depth: skyboxSize)
        let skyMaterial = SimpleMaterial(color: .blue.withAlphaComponent(0.5), roughness: 1.0, isMetallic: false)
        let skyboxEntity = ModelEntity(mesh: skyboxMesh, materials: [skyMaterial])
        
        // Make sure we see the sky from the inside
        skyboxEntity.scale = SIMD3<Float>(-1, 1, -1)
        
        sky.addChild(skyboxEntity)
        
        // Add clouds (simplified for this example)
        // Most clouds will be added dynamically as flying objects
        for _ in 0..<5 {
            let cloudSize = Float.random(in: 100...300)
            let cloudMesh = MeshResource.generateBox(width: cloudSize, height: cloudSize/3, depth: cloudSize)
            let cloudMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.8), roughness: 1.0, isMetallic: false)
            let cloudEntity = ModelEntity(mesh: cloudMesh, materials: [cloudMaterial])
            
            // Position clouds randomly in sky
            cloudEntity.position = SIMD3<Float>(
                Float.random(in: -5000...5000),
                Float.random(in: 500...3000),
                Float.random(in: -5000...5000)
            )
            
            sky.addChild(cloudEntity)
        }
        
        return sky
    }
    
    private func addLighting(to rootEntity: Entity) {
        // Create directional light
        let directionalLight = Entity()
        var directionalComponent = DirectionalLightComponent()
        directionalComponent.intensity = 1000  // Higher value needed in visionOS
        directionalLight.components[DirectionalLightComponent.self] = directionalComponent
        
        // Set light direction
        directionalLight.look(at: SIMD3<Float>(100, -100, 100), from: SIMD3<Float>(0, 0, 0), relativeTo: nil)
        
        rootEntity.addChild(directionalLight)
        
        // Create point light near the aircraft for better visibility
        let pointLight = Entity()
        var pointComponent = PointLightComponent()
        pointComponent.intensity = 500
        pointComponent.attenuationRadius = 100
        pointLight.components[PointLightComponent.self] = pointComponent
        
        // Position the light slightly above the starting position
        pointLight.position = SIMD3<Float>(0, 20, 0)
        
        rootEntity.addChild(pointLight)
    }
}

// MARK: - Flying Objects

// Types of flying objects
enum FlyingObjectType {
    case cloud
    case bird
    case aircraft
}

// Structure to represent a flying object
struct FlyingObject {
    let id: String
    let type: FlyingObjectType
    var position: SIMD3<Float>
    var scale: SIMD3<Float>
    var rotation: simd_quatf
}

// HUD display with flight instruments
struct FlightInstrumentsView: View {
    let altitude: Float
    let airspeed: Float
    let verticalSpeed: Float
    let heading: Float
    let roll: Float
    let pitch: Float
    let fps: Double
    
    var body: some View {
        HStack {
            // Left side instruments
            VStack(alignment: .leading) {
                Text("ALT: \(safeInt(altitude))m")
                Text("SPD: \(safeInt(airspeed))m/s")
                Text("V/S: \(safeInt(verticalSpeed))m/s")
            }
            
            Spacer()
            
            // Center - Attitude indicator
            AttitudeIndicatorView(pitch: pitch, roll: roll)
                .frame(width: 120, height: 120)
            
            Spacer()
            
            // Right side instruments
            VStack(alignment: .trailing) {
                Text("HDG: \(safeInt(heading))°")
                Text("ROLL: \(safeInt(roll))°")
                Text("PITCH: \(safeInt(pitch))°")
                Text("FPS: \(safeInt(fps))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .padding()
    }
    
    // Safely convert Float to Int, handling extreme values
    private func safeInt(_ value: Float) -> Int {
        if value.isInfinite || value.isNaN {
            return 0
        }
        
        if value > Float(Int.max) {
            return Int.max
        }
        
        if value < Float(Int.min) {
            return Int.min
        }
        
        return Int(value)
    }
    
    // Overload for Double
    private func safeInt(_ value: Double) -> Int {
        if value.isInfinite || value.isNaN {
            return 0
        }
        
        if value > Double(Int.max) {
            return Int.max
        }
        
        if value < Double(Int.min) {
            return Int.min
        }
        
        return Int(value)
    }

}

// Simplified attitude indicator
struct AttitudeIndicatorView: View {
    let pitch: Float
    let roll: Float
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(Color.black)
            
            // Horizon line
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.blue, .brown]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 110, height: 110)
                // Offset based on pitch
                .offset(y: CGFloat(pitch / 90.0 * 50.0))
                // Rotate based on roll
                .rotationEffect(Angle(degrees: Double(roll)))
                .clipShape(Circle())
            
            // Aircraft reference
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 40, height: 2)
            
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 2, height: 40)
            
            // Circle border
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 110, height: 110)
        }
    }
}

// Throttle control view
struct ThrottleControlView: View {
    @Binding var value: Float
    
    var body: some View {
        VStack {
            Text("Throttle")
                .font(.caption)
            
            ZStack(alignment: .bottom) {
                // Throttle track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 150)
                    .cornerRadius(15)
                
                // Throttle value
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.red, .orange, .green]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 30, height: CGFloat(value) * 150)
                    .cornerRadius(15)
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let height: CGFloat = 150
                        let yOffset = min(max(0, gesture.location.y), height)
                        let normalizedValue = 1.0 - Float(yOffset / height)
                        value = normalizedValue
                    }
            )
        }
    }
}

// Flight stick control
struct FlightStickView: View {
    @Binding var offset: CGSize
    @State private var isDragging = false
    
    // Constants
    let maxOffset: CGFloat = 100
    let stickSize: CGFloat = 80
    let baseSize: CGFloat = 150
    
    var body: some View {
        ZStack {
            // Base
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: baseSize, height: baseSize)
            
            // Center marker
            Circle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: 20, height: 20)
            
            // Cross
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 2, height: baseSize)
            
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: baseSize, height: 2)
            
            // Stick
            Circle()
                .fill(isDragging ? Color.orange : Color.gray)
                .frame(width: stickSize, height: stickSize)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            isDragging = true
                            
                            // Calculate new position
                            let newX = gesture.translation.width
                            let newY = gesture.translation.height
                            
                            // Calculate distance from center
                            let distance = sqrt(newX*newX + newY*newY)
                            
                            // If distance exceeds maximum, scale it down
                            if distance > maxOffset {
                                let scale = maxOffset / distance
                                offset = CGSize(
                                    width: newX * scale,
                                    height: newY * scale
                                )
                            } else {
                                offset = gesture.translation
                            }
                        }
                        .onEnded { _ in
                            // Return to center when released
                            withAnimation(.spring()) {
                                offset = .zero
                                isDragging = false
                            }
                        }
                )
            
            // Labels
            Text("Pitch/Roll")
                .font(.caption)
                .position(x: baseSize/2, y: baseSize + 20)
        }
        .frame(width: baseSize, height: baseSize + 40)
    }
}

// Rudder control
struct RudderControlView: View {
    @Binding var value: Float
    
    var body: some View {
        VStack {
            Text("Rudder")
                .font(.caption)
            
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 30)
                
                // Value indicator
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.blue)
                    .frame(width: 40, height: 30)
                    .offset(x: CGFloat(value) * 50)
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let width: CGFloat = 150
                        let xOffset = min(max(-50, gesture.location.x - width/2), 50)
                        let normalizedValue = Float(xOffset / 50)
                        value = normalizedValue
                    }
                    .onEnded { _ in
                        // Return to center
                        withAnimation(.spring()) {
                            value = 0
                        }
                    }
            )
        }
    }
}

// Pause menu overlay
struct PauseMenuView: View {
    var viewModel: FlightViewModel
    var onReturnToMenu: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("PAUSED")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button("Resume") {
                    viewModel.resumeGame()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Restart Mission") {
                    viewModel.startGame()
                }
                .buttonStyle(.bordered)
                
                Button("Quit to Menu") {
                    // Change to menu state
                    viewModel.gameState = .menu
                    onReturnToMenu()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

// Game over screen
struct GameOverView: View {
    var viewModel: FlightViewModel
    var onReturnToMenu: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("MISSION FAILED")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Score: \(viewModel.missionProgress.score)")
                    Text("Time: \(safeInt(viewModel.missionProgress.timeElapsed))s")
                    Text("Checkpoints: \(viewModel.missionProgress.checkpointsCompleted)/\(viewModel.missionProgress.totalCheckpoints)")
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                Button("Retry Mission") {
                    viewModel.startGame()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Quit to Menu") {
                    // Change to menu state
                    viewModel.gameState = .menu
                    onReturnToMenu()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
    
    // Helper function for safe conversion to Int
    private func safeInt(_ value: TimeInterval) -> Int {
        if value.isInfinite || value.isNaN {
            return 0
        }
        
        if value > Double(Int.max) {
            return Int.max
        }
        
        if value < Double(Int.min) {
            return Int.min
        }
        
        return Int(value)
    }
}

// Mission complete screen
struct MissionCompleteView: View {
    var viewModel: FlightViewModel
    var onReturnToMenu: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("MISSION COMPLETE")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Score: \(viewModel.missionProgress.score)")
                    Text("Time: \(safeInt(viewModel.missionProgress.timeElapsed))s")
                    Text("Checkpoints: \(viewModel.missionProgress.checkpointsCompleted)/\(viewModel.missionProgress.totalCheckpoints)")
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                Button("Next Mission") {
                    // Load next mission logic would go here
                    // For now, return to menu
                    viewModel.gameState = .menu
                    onReturnToMenu()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Retry Mission") {
                    viewModel.startGame()
                }
                .buttonStyle(.bordered)
                
                Button("Quit to Menu") {
                    // Change to menu state
                    viewModel.gameState = .menu
                    onReturnToMenu()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
    
    // Helper function for safe conversion to Int
    private func safeInt(_ value: TimeInterval) -> Int {
        if value.isInfinite || value.isNaN {
            return 0
        }
        
        if value > Double(Int.max) {
            return Int.max
        }
        
        if value < Double(Int.min) {
            return Int.min
        }
        
        return Int(value)
    }
}
