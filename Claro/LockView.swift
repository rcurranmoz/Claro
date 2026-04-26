import SwiftUI
import LocalAuthentication

struct LockView: View {
    let onUnlock: () -> Void
    @State private var biometricLabel = "Biometrics"
    @State private var biometricIcon  = "lock.fill"

    var body: some View {
        ZStack {
            Color.claroBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.claroAccent.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(Color.claroAccent.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.claroAccent)
                }
                .padding(.bottom, 28)

                Text("Claro Lens")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text("Your health documents are locked.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.claroSubtle)
                    .padding(.top, 6)

                Spacer()

                Button(action: authenticate) {
                    Label("Unlock with \(biometricLabel)", systemImage: biometricIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.claroAccent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            detectBiometricType()
            authenticate()
        }
    }

    private func detectBiometricType() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }
        if ctx.biometryType == .faceID {
            biometricLabel = "Face ID"
            biometricIcon  = "faceid"
        } else {
            biometricLabel = "Touch ID"
            biometricIcon  = "touchid"
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        var err: NSError?
        let policy: LAPolicy = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        ctx.evaluatePolicy(policy, localizedReason: "Unlock Claro Lens") { success, _ in
            if success { DispatchQueue.main.async { onUnlock() } }
        }
    }
}
