//
//  ContentView.swift
//  Mezzanine
//
//  Created by Coder on 2/25/25.
//
import SwiftUI

struct ContentView: View {
    @State private var viewModel = FlightViewModel()
    @State private var activeScreen: GameScreen = .mainMenu
    
    enum GameScreen {
        case mainMenu
        case cockpit
    }
    
    var body: some View {
        ZStack {
            if activeScreen == .mainMenu {
                MainMenuView(onStartFlight: { mission, aircraftType, difficulty in
                    // Configure the flight before starting
                    setupAndStartFlight(mission: mission, aircraftType: aircraftType, difficulty: difficulty)
                    
                    // Transition to cockpit view
                    withAnimation {
                        activeScreen = .cockpit
                    }
                })
            } else {
                CockpitView(viewModel: viewModel, onReturnToMenu: {
                    // Return to main menu
                    withAnimation {
                        activeScreen = .mainMenu
                    }
                })
            }
        }
    }
    
    private func setupAndStartFlight(mission: Mission?, aircraftType: AircraftType, difficulty: GameDifficulty) {
        // Create a new ViewModel with selected settings
        viewModel = FlightViewModel(aircraftType: aircraftType)
        
        // Configure mission settings
        if let mission = mission {
            var missionWithDifficulty = mission
            missionWithDifficulty.difficulty = difficulty
            
            // Start the game with selected mission
            viewModel.startGame(mission: missionWithDifficulty)
        } else {
            // Start with default settings
            viewModel.startGame()
        }
    }
}

#Preview {
    ContentView()
}
