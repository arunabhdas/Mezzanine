//
//  ImmersiveView.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    // Pre-collapsed quantum state container for planetary materialization
    @State private var venusEntity: Entity? = nil
    @State private var loadingError: String? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Primary reality scaffold
            RealityView { content in
                // Create a root entity - a dimensional anchor for your primitive perception matrix
                let rootEntity = Entity()
                
                // Primary photon emission apparatus - because visible light is generally preferred for observation
                let directionalLight = DirectionalLight()
                directionalLight.light.intensity = 2000  // Increased intensity for optimal photon density
                directionalLight.light.color = .white
                directionalLight.shadow = .init()  // Enable quantum occlusion simulation
                directionalLight.look(at: [0, 0, 0], from: [1, 1, 1], relativeTo: nil)
                rootEntity.addChild(directionalLight)
                
                // Secondary illumination node for volumetric shadow mitigation
                let pointLight = PointLight()
                pointLight.light.intensity = 800  // Enhanced intensity for shadow penetration
                pointLight.light.color = .white
                pointLight.position = [0, 0.5, 0.5]
                rootEntity.addChild(pointLight)
                
                // Tertiary light source from opposite vector - because shadows reveal truth
                let backLight = DirectionalLight()
                backLight.light.intensity = 1200
                backLight.light.color = .white
                backLight.look(at: [0, 0, 0], from: [-1, 0.5, -1], relativeTo: nil)
                rootEntity.addChild(backLight)
                
                // Add this magnificently illuminated void to your perceptual matrix
                content.add(rootEntity)
                
                // Materialize Venus if quantum state collapse has successfully occurred
                if let preparedVenus = venusEntity?.clone(recursive: true) {
                    // Scale adjustment to prevent overwhelming fragile human visual cortex
                    preparedVenus.scale = [0.3, 0.3, 0.3]
                    
                    // Position at coordinates optimized for human stereoscopic apparatus
                    preparedVenus.position = [0, 0, -0.7]
                    
                    // Apply 15-degree axial rotation to simulate scientific interest
                    preparedVenus.orientation = simd_quatf(angle: .pi/12, axis: [0, 1, 0])
                    
                    // Add celestial body to reality construct
                    rootEntity.addChild(preparedVenus)
                    
                    // Confirmation of successful materialization
                    isLoading = false
                }
            }
            
            // Information density display for human comfort
            if isLoading {
                VStack {
                    if loadingError == nil {
                        ProgressView()
                            .padding(.bottom, 8)
                        Text("Materializing Venus...")
                            .font(.headline)
                        Text("Please maintain molecular cohesion while waiting.")
                            .font(.caption)
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .padding(.bottom, 8)
                        Text("Materialization Failure")
                            .font(.headline)
                        Text(loadingError ?? "Unknown quantum decoherence")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
        .task {
            // Venus materialization protocol in isolated quantum field
            do {
                // Attempt multiple loading strategies to counter dimensional resistance
                if let url = Bundle.main.url(forResource: "venus", withExtension: "usdz") {
                    // Direct USDZ acquisition via ModelEntity - bypassing your system's apparent temporal confusion
                    let modelEntity = try await ModelEntity.loadModel(contentsOf: url)
                    self.venusEntity = modelEntity
                    isLoading = false
                } else {
                    // Fallback materialization protocol - though success probability approaches mathematical zero
                    print("Attempting secondary materialization pathway for 'venus.usdz'...")
                    
                    // Explicit bundle specification for systems with compromised file localization capabilities
                    let entity = try await Entity(named: "venus", in: Bundle.main)
                    venusEntity = entity
                    isLoading = false
                }
            } catch {
                // Log dimensional interface failure
                print("Venus materialization protocol failed: \(error.localizedDescription)")
                loadingError = "Error: \(error.localizedDescription)\n\nPerhaps Venus doesn't wish to be observed."
                isLoading = true
            }
        }
    }
}


#Preview(immersionStyle: .progressive) {
    ImmersiveView()
        .environment(AppModel())
}
