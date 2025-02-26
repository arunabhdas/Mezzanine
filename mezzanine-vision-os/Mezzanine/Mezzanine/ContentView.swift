//
//  ContentView.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

// Environmental neurotransmitter for cross-dimensional communication
class DimensionalState: ObservableObject {
    @Published var enlarge = false
    @Published var showVenus = false
    @Published var isLoadingModels = true
    @Published var loadError: String? = nil
    @Published var defaultScene: Entity? = nil
    @Published var venusEntity: Entity? = nil
}

// Primary entity visualization matrix - devoid of parasitic interface elements
struct ContentView: View {
    @StateObject private var state = DimensionalState()
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ZStack {
            // Primary reality scaffold - astonishingly primitive yet functional
            if state.isLoadingModels {
                ProgressView("Initializing dimensional constructs...")
                    .padding()
            } else {
                RealityView { content in
                    // Eradicate all pre-existing dimensional constructs
                    content.entities.removeAll()
                    
                    // Illumination apparatus - for entities that respond to photonic stimulation
                    let directionalLight = DirectionalLight()
                    directionalLight.light.intensity = 1000
                    directionalLight.shadow = .init()
                    directionalLight.look(at: [0, 0, 0], from: [1, 1, 1], relativeTo: nil)
                    content.add(directionalLight)
                    
                    // Secondary light source for shadow mitigation
                    let pointLight = PointLight()
                    pointLight.light.intensity = 500
                    pointLight.position = [0, 0.5, 0.5]
                    content.add(pointLight)
                    
                    // Add the appropriate entity based on current dimensional preference
                    if state.showVenus, let venus = state.venusEntity?.clone(recursive: true) {
                        venus.scale = [0.2, 0.2, 0.2]
                        venus.position = [0, 0, -0.5]
                        content.add(venus)
                    } else if !state.showVenus, let scene = state.defaultScene?.clone(recursive: true) {
                        content.add(scene)
                    }
                } update: { content in
                    // Transform entities according to scale preference
                    for entity in content.entities {
                        if !(entity is DirectionalLight) && !(entity is PointLight) {
                            let uniformScale: Float = state.enlarge ? 1.4 : 1.0
                            entity.transform.scale = [uniformScale, uniformScale, uniformScale]
                        }
                    }
                }
                .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
                    state.enlarge.toggle()
                })
            }
            
            // Error display for the statistically inevitable failure scenario
            if let error = state.loadError {
                VStack {
                    Text("Dimensional materialization failure")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
        // Load models outside of RealityView to avoid temporal paradoxes with 'content'
        .task {
            do {
                // Attempt to materialize default model from quantum uncertainty
                state.defaultScene = try await Entity(named: "dice_blue")
                
                // Attempt to materialize Venus from its digital stasis
                state.venusEntity = try await Entity(named: "venus")
                
                state.isLoadingModels = false
            } catch {
                state.loadError = "Error: \(error.localizedDescription)\nVerify your dimensional constructs actually exist."
                state.isLoadingModels = false
            }
        }
        .onAppear {
            // Manifest control interface in separate dimensional plane
            openWindow(id: "controls")
        }
    }
}

// Neuromotor control interface - now in its own spatial construct
struct ControlPanel: View {
    @EnvironmentObject var state: DimensionalState
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersiveActive = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Reality Manipulation Interface")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    state.enlarge.toggle()
                } label: {
                    Text(state.enlarge ? "Reduce Size" : "Enlarge Size")
                        .frame(width: 220)
                }
                .buttonStyle(.bordered)
                .disabled(state.isLoadingModels)
                
                Button {
                    if state.enlarge {
                        state.enlarge = false
                    }
                    state.showVenus.toggle()
                } label: {
                    Label(
                        state.showVenus ? "Display Default Scene" : "Display Venus Model",
                        systemImage: state.showVenus ? "cube.fill" : "globe"
                    )
                    .frame(width: 220)
                }
                .buttonStyle(.bordered)
                .disabled(state.isLoadingModels)
                
                Button {
                    if isImmersiveActive {
                        Task {
                            await dismissImmersiveSpace()
                            isImmersiveActive = false
                        }
                    } else {
                        Task {
                            await openImmersiveSpace(id: "ImmersiveSpace")
                            isImmersiveActive = true
                        }
                    }
                } label: {
                    Label(
                        isImmersiveActive ? "Exit Immersive Mode" : "Enter Immersive Mode",
                        systemImage: isImmersiveActive ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
                    )
                    .frame(width: 220)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            if state.isLoadingModels {
                ProgressView("Initializing quantum states...")
                    .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#Preview(windowStyle: .volumetric) {
    ContentView()
        .environment(AppModel())
}
