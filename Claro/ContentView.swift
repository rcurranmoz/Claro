import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding")    private var hasSeenOnboarding    = false
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @State private var isLocked    = true
    @State private var lastBgDate  = Date()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if biometricLockEnabled && isLocked {
                LockView { isLocked = false }
            } else if hasSeenOnboarding {
                HomeView()
            } else {
                OnboardingView(onComplete: { hasSeenOnboarding = true })
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lastBgDate = Date()
            case .active:
                if biometricLockEnabled && Date().timeIntervalSince(lastBgDate) > 60 {
                    isLocked = true
                }
            default: break
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(DocumentStore())
        .environment(FHIRService.shared)
}
