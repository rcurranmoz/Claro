import Foundation
import AuthenticationServices

@Observable
final class AuthService: NSObject {
    private(set) var isSignedIn: Bool
    private(set) var userId: String
    private(set) var displayName: String

    private let userIdKey      = "claro.auth.userId"
    private let displayNameKey = "claro.auth.displayName"

    override init() {
        userId      = UserDefaults.standard.string(forKey: "claro.auth.userId") ?? ""
        displayName = UserDefaults.standard.string(forKey: "claro.auth.displayName") ?? ""
        isSignedIn  = !(UserDefaults.standard.string(forKey: "claro.auth.userId") ?? "").isEmpty
        super.init()
        if isSignedIn { checkCredentialState() }
    }

    func signIn(credential: ASAuthorizationAppleIDCredential) {
        userId = credential.user
        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }.joined(separator: " ")
            if !name.isEmpty { displayName = name }
        }
        UserDefaults.standard.set(userId,      forKey: userIdKey)
        UserDefaults.standard.set(displayName, forKey: displayNameKey)
        isSignedIn = true
    }

    func signOut() {
        userId = ""; displayName = ""
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        isSignedIn = false
    }

    private func checkCredentialState() {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userId) { [weak self] state, _ in
            if state == .revoked || state == .notFound {
                DispatchQueue.main.async { self?.signOut() }
            }
        }
    }
}
