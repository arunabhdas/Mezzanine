//
//  MainMenuView.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//
import SwiftUI
import RealityKit

struct MainMenuView: View {
    var onStartFlight: (Mission?, AircraftType, GameDifficulty) -> Void
    @State private var selectedMission: Mission?
    @State private var selectedAircraftType: AircraftType = .lightPlane
    @State private var difficulty: GameDifficulty = .normal
    @State private var showingMissionSelect = false
    @State private var showingSettingsView = false
    
    // Available missions
    private let availableMissions: [Mission] = [
        Mission(
            id: "training",
            name: "Training Flight",
            description: "Learn the basics of flight in calm conditions.",
            startPosition: SIMD3<Float>(0, 100, 0),
            startRotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            checkpoints: [
                Checkpoint(
                    id: "cp1",
                    position: SIMD3<Float>(500, 100, 0),
                    radius: 100,
                    requiredAltitudeMin: 50,
                    requiredAltitudeMax: 150,
                    requiredSpeed: nil,
                    nextCheckpointDirection: nil
                )
            ],
            timeLimit: nil,
            environmentSettings: EnvironmentConditions(
                windDirection: SIMD3<Float>(1, 0, 0),
                windSpeed: 2.0,
                turbulence: 0.1,
                visibility: 10000,
                timeOfDay: 12.0
            ),
            difficulty: .easy
        ),
        
        Mission(
            id: "canyon",
            name: "Canyon Run",
            description: "Navigate through a narrow canyon at high speed.",
            startPosition: SIMD3<Float>(0, 200, 0),
            startRotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            checkpoints: [
                Checkpoint(
                    id: "cp1",
                    position: SIMD3<Float>(500, 150, 0),
                    radius: 100,
                    requiredAltitudeMin: 100,
                    requiredAltitudeMax: 200,
                    requiredSpeed: 50,
                    nextCheckpointDirection: nil
                ),
                Checkpoint(
                    id: "cp2",
                    position: SIMD3<Float>(1000, 100, 500),
                    radius: 100,
                    requiredAltitudeMin: 50,
                    requiredAltitudeMax: 150,
                    requiredSpeed: nil,
                    nextCheckpointDirection: nil
                )
            ],
            timeLimit: 180,
            environmentSettings: EnvironmentConditions(
                windDirection: SIMD3<Float>(1, 0, 1),
                windSpeed: 5.0,
                turbulence: 0.3,
                visibility: 8000,
                timeOfDay: 16.0
            ),
            difficulty: .normal
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            BackgroundView()
            
            // Main menu content
            VStack(spacing: 30) {
                // Title
                Text("MEZZANINE")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 5)
                
                Text("visionOS Flight Simulator")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 3)
                
                Spacer()
                
                // Main menu buttons
                 VStack(spacing: 20) {
                     Button("Quick Flight") {
                         // Start with default training mission
                         selectedMission = availableMissions.first
                         onStartFlight(selectedMission, selectedAircraftType, difficulty)
                     }
                     .buttonStyle(MenuButtonStyle())
                     
                     Button("Mission Select") {
                         showingMissionSelect = true
                     }
                     .buttonStyle(MenuButtonStyle())
                     
                     Button("Settings") {
                         showingSettingsView = true
                     }
                     .buttonStyle(MenuButtonStyle())
                 }
                
                Spacer()
                
                // Aircraft selection
                VStack {
                    Text("Select Aircraft")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        AircraftSelectionButton(
                            aircraftType: .lightPlane,
                            isSelected: selectedAircraftType == .lightPlane,
                            onSelect: { selectedAircraftType = .lightPlane }
                        )
                        
                        AircraftSelectionButton(
                            aircraftType: .jetFighter,
                            isSelected: selectedAircraftType == .jetFighter,
                            onSelect: { selectedAircraftType = .jetFighter }
                        )
                        
                        AircraftSelectionButton(
                            aircraftType: .heavyTransport,
                            isSelected: selectedAircraftType == .heavyTransport,
                            onSelect: { selectedAircraftType = .heavyTransport }
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                
                // Difficulty selection
                VStack {
                    Text("Difficulty")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker("", selection: $difficulty) {
                        Text("Easy").tag(GameDifficulty.easy)
                        Text("Normal").tag(GameDifficulty.normal)
                        Text("Realistic").tag(GameDifficulty.realistic)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                
                Spacer()
                
                // Start button
                Button("START FLIGHT") {
                    onStartFlight(selectedMission, selectedAircraftType, difficulty)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 40)
            }
            .padding()
            
            // Mission select sheet
            if showingMissionSelect {
                MissionSelectView(
                    missions: availableMissions,
                    selectedMission: $selectedMission,
                    isShowing: $showingMissionSelect,
                    onStart: {
                        if let mission = selectedMission {
                            onStartFlight(mission, selectedAircraftType, difficulty)
                        }
                    }
                )
            }
            
            // Settings view sheet
            if showingSettingsView {
                SettingsView(isShowing: $showingSettingsView)
            }
        }
    }
}

// Background view with animated sky and clouds
struct BackgroundView: View {
    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                gradient: Gradient(colors: [.blue, Color(red: 0.4, green: 0.6, blue: 0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // Animated clouds could be added here in a real implementation
            
            // Optional 3D aircraft flying in background
            RealityView { content in
                // Create an entity for the background aircraft
                let aircraftEntity = createBackgroundAircraft()
                
                // Add to the scene
                content.add(aircraftEntity)
                
                // Set up animation
                animateAircraft(aircraftEntity)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func createBackgroundAircraft() -> Entity {
        // In a real implementation, load a 3D model
        // For now, create a simple proxy
        let aircraft = Entity()
        
        // Add a simple shape as a placeholder
        let boxMesh = MeshResource.generateBox(size: 5)
        let material = SimpleMaterial(color: .white, roughness: 0.5, isMetallic: true)
        let modelEntity = ModelEntity(mesh: boxMesh, materials: [material])
        
        aircraft.addChild(modelEntity)
        
        // Position it in the background
        aircraft.position = SIMD3<Float>(-50, 30, -100)
        
        return aircraft
    }
    
    private func animateAircraft(_ aircraft: Entity) {
        // In a real implementation, set up a more complex animation path
        // For now, just a simple movement
        
        // Create animation to fly across the scene
        let animation = Transform(
            rotation: simd_quatf(angle: 0.2, axis: SIMD3<Float>(0, 1, 0)),
            translation: SIMD3<Float>(200, 0, 0)
        )
        
        // Apply animation
        aircraft.move(to: animation, relativeTo: aircraft, duration: 20, timingFunction: .linear)
    }
}

// Button styles
struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .padding()
            .frame(width: 250)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(configuration.isPressed ? 0.7 : 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 5)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title.bold())
            .padding()
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(configuration.isPressed ? 0.7 : 0.9))
                    .shadow(color: .black.opacity(0.3), radius: 5)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Aircraft selection button
struct AircraftSelectionButton: View {
    let aircraftType: AircraftType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack {
                // Aircraft image placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.5))
                        .frame(width: 100, height: 80)
                    
                    // Aircraft icon/image would go here
                    Text(aircraftIcon)
                        .font(.system(size: 40))
                }
                
                Text(aircraftName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .gray)
            }
        }
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    var aircraftName: String {
        switch aircraftType {
        case .lightPlane:
            return "Light Aircraft"
        case .jetFighter:
            return "Jet Fighter"
        case .heavyTransport:
            return "Heavy Transport"
        }
    }
    
    var aircraftIcon: String {
        switch aircraftType {
        case .lightPlane:
            return "✈️"
        case .jetFighter:
            return "🛩️"
        case .heavyTransport:
            return "🛫"
        }
    }
}

// Mission select view
struct MissionSelectView: View {
    let missions: [Mission]
    @Binding var selectedMission: Mission?
    @Binding var isShowing: Bool
    let onStart: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            VStack {
                // Header
                HStack {
                    Text("Select Mission")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { isShowing = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // Mission list
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(missions, id: \.id) { mission in
                            MissionCard(
                                mission: mission,
                                isSelected: selectedMission?.id == mission.id,
                                onSelect: {
                                    selectedMission = mission
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // Buttons
                HStack {
                    Button("Back") {
                        isShowing = false
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Start Mission") {
                        isShowing = false
                        onStart()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedMission == nil)
                }
                .padding()
            }
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(40)
        }
    }
}

// Mission card view
struct MissionCard: View {
    let mission: Mission
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(mission.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(mission.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        // Difficulty
                        Label(difficultyText, systemImage: "speedometer")
                            .font(.caption)
                        
                        Spacer()
                        
                        // Time limit if any
                        if let timeLimit = mission.timeLimit {
                            Label("\(safeInt(timeLimit))s", systemImage: "clock")
                                .font(.caption)
                        }
                        
                        // Checkpoints
                        Label("\(mission.checkpoints.count)", systemImage: "flag")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var difficultyText: String {
        switch mission.difficulty {
        case .easy:
            return "Easy"
        case .normal:
            return "Normal"
        case .realistic:
            return "Realistic"
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

// Settings view
struct SettingsView: View {
    @Binding var isShowing: Bool
    @State private var soundVolume: Double = 0.7
    @State private var musicVolume: Double = 0.5
    @State private var controlSensitivity: Double = 0.5
    @State private var showFramerate: Bool = true
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            VStack {
                // Header
                HStack {
                    Text("Settings")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { isShowing = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // Settings
                Form {
                    Section(header: Text("Audio")) {
                        VStack(alignment: .leading) {
                            Text("Sound Effects: \(Int(soundVolume * 100))%")
                            Slider(value: $soundVolume)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Music: \(Int(musicVolume * 100))%")
                            Slider(value: $musicVolume)
                        }
                    }
                    
                    Section(header: Text("Controls")) {
                        VStack(alignment: .leading) {
                            Text("Sensitivity: \(Int(controlSensitivity * 100))%")
                            Slider(value: $controlSensitivity)
                        }
                    }
                    
                    Section(header: Text("Display")) {
                        Toggle("Show FPS Counter", isOn: $showFramerate)
                    }
                }
                
                // Buttons
                HStack {
                    Button("Reset to Defaults") {
                        soundVolume = 0.7
                        musicVolume = 0.5
                        controlSensitivity = 0.5
                        showFramerate = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button("Save") {
                        // Save settings logic would go here
                        isShowing = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(40)
        }
    }
}
