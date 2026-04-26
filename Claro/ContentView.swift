//
//  ContentView.swift
//  Claro
//
//  Created by Ryan Curran on 4/26/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            HomeView()
        } else {
            OnboardingView(onComplete: { hasSeenOnboarding = true })
        }
    }
}

#Preview {
    ContentView()
        .environment(DocumentStore())
}
