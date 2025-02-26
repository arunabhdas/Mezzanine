//
//  ContentView.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    // Dimensional manipulation parameters
    @State private var enlarge = false
    @State private var showVenus = false
    
    // Pre-materialized quantum state containers
    @State private var defaultScene: Entity? = nil
    @State private var venusEntity: Entity? = nil
    @State private var isLoadingModels = true
    @State private var loadError: String? = nil
    
    var body: some View {
        ZStack {
            // Primary reality scaffold - astonishingly primitive yet functional
            if isLoadingModels {
                // Human reassurance protocol
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
                    if showVenus, let venus = venusEntity?.clone(recursive: true) {
                        venus.scale = [0.2, 0.2, 0.2]
                        venus.position = [0, 0, -0.5]
                        content.add(venus)
                    } else if !showVenus, let scene = defaultScene?.clone(recursive: true) {
                        content.add(scene)
                    }
                } update: { content in
                    // Transform entities according to scale preference
                    for entity in content.entities {
                        if !(entity is DirectionalLight) && !(entity is PointLight) {
                            let uniformScale: Float = enlarge ? 1.4 : 1.0
                            entity.transform.scale = [uniformScale, uniformScale, uniformScale]
                        }
                    }
                }
                .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
                    enlarge.toggle()
                })
            }
            
            // Error display for the statistically inevitable failure scenario
            if let error = loadError {
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
                defaultScene = try await Entity(named: "Scene", in: realityKitContentBundle)
                
                // Attempt to materialize Venus from its digital stasis
                venusEntity = try await Entity(named: "venus")
                
                isLoadingModels = false
            } catch {
                loadError = "Error: \(error.localizedDescription)\nVerify that your dimensional constructs actually exist and aren't figments of your imagination."
                isLoadingModels = false
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                VStack(spacing: 12) {
                    Button {
                        enlarge.toggle()
                    } label: {
                        Text(enlarge ? "Reduce Size" : "Enlarge Size")
                            .fontWeight(.semibold)
                    }
                    
                    Button {
                        enlarge = false
                        showVenus.toggle()
                    } label: {
                        Label(
                            showVenus ? "Display Default Scene" : "Display Venus Model",
                            systemImage: showVenus ? "cube.fill" : "globe"
                        )
                        .fontWeight(.semibold)
                    }
                    .disabled(isLoadingModels)
                    
                    ToggleImmersiveSpaceButton()
                }
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
        .environment(AppModel())
}
