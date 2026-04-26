import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.claroBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.claroAccent.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.claroAccent)
                    }
                    Text("Claro Lens")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your personal medical billing advocate")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.claroSubtle)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sign-in area
                VStack(spacing: 16) {
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.claroDanger)
                            .multilineTextAlignment(.center)
                    }

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        handleResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Your medical records never leave your device.\nClaro only uses Apple ID to protect your account.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.claroSubtle.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            auth.signIn(credential: credential)
        case .failure(let error):
            let nsErr = error as NSError
            guard nsErr.domain == ASAuthorizationErrorDomain,
                  nsErr.code == ASAuthorizationError.canceled.rawValue else {
                errorMessage = error.localizedDescription
                return
            }
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
