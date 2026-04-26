import Foundation
import AuthenticationServices
import CryptoKit
import UIKit
import SwiftUI

// MARK: - FHIR Service

@Observable
final class FHIRService: NSObject {
    static let shared = FHIRService()

    var isConnected: Bool { accessToken != nil }
    var isAuthenticating = false
    var lastError: String?

    private var accessToken: String?
    private var tokenExpiry: Date?
    private var patientId: String?

    private let clientId        = Config.Epic.sandboxClientID
    private let redirectURI     = Config.Epic.redirectURI
    private let fhirBase        = Config.Epic.sandboxFHIRBase
    private let authEndpoint    = "https://fhir.epic.com/interconnect-fhir-oauth/oauth2/authorize"
    private let tokenEndpoint   = "https://fhir.epic.com/interconnect-fhir-oauth/oauth2/token"

    private let tokenKey        = "claro.fhir.accessToken"
    private let patientKey      = "claro.fhir.patientId"

    override init() {
        super.init()
        accessToken = UserDefaults.standard.string(forKey: tokenKey)
        patientId   = UserDefaults.standard.string(forKey: patientKey)
    }

    // MARK: - Auth

    func authenticate(presentingWindow: ASPresentationAnchor) async {
        isAuthenticating = true
        lastError = nil
        do {
            let (verifier, challenge) = pkce()
            let state = UUID().uuidString

            var components = URLComponents(string: authEndpoint)!
            components.queryItems = [
                .init(name: "response_type",         value: "code"),
                .init(name: "client_id",             value: clientId),
                .init(name: "redirect_uri",          value: redirectURI),
                .init(name: "scope",                 value: scopes),
                .init(name: "state",                 value: state),
                .init(name: "code_challenge",        value: challenge),
                .init(name: "code_challenge_method", value: "S256"),
                .init(name: "aud",                   value: fhirBase),
            ]

            let callbackURL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: components.url!,
                    callbackURLScheme: "com.ryancurran.ios.Claro"
                ) { url, error in
                    if let url { continuation.resume(returning: url) }
                    else { continuation.resume(throwing: error ?? FHIRError.authCancelled) }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            let code = try extractCode(from: callbackURL, expectedState: state)
            try await exchangeToken(code: code, verifier: verifier)
        } catch FHIRError.authCancelled {
            // user tapped cancel — no error to show
        } catch {
            lastError = error.localizedDescription
        }
        isAuthenticating = false
    }

    func disconnect() {
        accessToken = nil
        patientId   = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: patientKey)
    }

    // MARK: - Coverage → InsuranceProfile

    func fetchCoverage() async throws -> InsuranceProfile? {
        guard let pid = patientId else { throw FHIRError.notAuthenticated }
        let bundle: FHIRBundle = try await fhirGet("Coverage?patient=\(pid)&status=active")
        guard let entry = bundle.entry?.first,
              let resource = entry.resource else { return nil }
        return insuranceProfile(from: resource)
    }

    // MARK: - EOB list (for future use)

    func fetchEOBSummaries() async throws -> [EOBSummary] {
        guard let pid = patientId else { throw FHIRError.notAuthenticated }
        let bundle: FHIRBundle = try await fhirGet("ExplanationOfBenefit?patient=\(pid)&_count=20")
        return bundle.entry?.compactMap { eobSummary(from: $0.resource) } ?? []
    }

    // MARK: - Private helpers

    private func fhirGet<T: Decodable>(_ path: String) async throws -> T {
        guard let token = accessToken else { throw FHIRError.notAuthenticated }
        guard let url = URL(string: "\(fhirBase)/\(path)") else { throw FHIRError.badURL }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 { disconnect() }
            throw FHIRError.httpError(code)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func exchangeToken(code: String, verifier: String) async throws {
        var req = URLRequest(url: URL(string: tokenEndpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  redirectURI,
            "client_id":     clientId,
            "code_verifier": verifier,
        ]
        req.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
                             .joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw FHIRError.tokenExchangeFailed
        }
        accessToken = token
        patientId   = json["patient"] as? String
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(patientId, forKey: patientKey)
    }

    private func extractCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw FHIRError.badCallback
        }
        return code
    }

    private func pkce() -> (verifier: String, challenge: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier  = Data(bytes).base64URLEncoded()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
        return (verifier, challenge)
    }

    private let scopes = "openid fhirUser patient/Coverage.read patient/ExplanationOfBenefit.read patient/Patient.read patient/Observation.read"

    // MARK: - FHIR → model conversions

    private func insuranceProfile(from resource: FHIRResource?) -> InsuranceProfile? {
        guard let r = resource else { return nil }
        let insurer  = r.payor?.first?.display ?? ""
        let planName = r.`class`?.first(where: { $0.type?.coding?.first?.code == "plan" })?.name ?? ""
        let memberId = r.identifier?.first(where: { $0.type?.coding?.first?.code == "MB" })?.value ?? ""
        guard !insurer.isEmpty else { return nil }
        return InsuranceProfile(
            insurerName: insurer, planName: planName, memberId: memberId,
            deductibleAnnual: 0, deductibleMet: 0, outOfPocketMax: 0, outOfPocketMet: 0
        )
    }

    private func eobSummary(from resource: FHIRResource?) -> EOBSummary? {
        guard let r = resource, r.resourceType == "ExplanationOfBenefit" else { return nil }
        let total    = r.total?.first(where: { $0.category?.coding?.first?.code == "submitted" })?.amount?.value
        let patient  = r.total?.first(where: { $0.category?.coding?.first?.code == "patientpay" })?.amount?.value
        let dateStr  = r.billablePeriod?.start ?? ""
        return EOBSummary(date: dateStr, totalBilled: total, patientOwes: patient)
    }
}

// MARK: - Presentation anchor

extension FHIRService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Lightweight FHIR JSON models

struct FHIRBundle: Decodable {
    let entry: [FHIREntry]?
}
struct FHIREntry: Decodable {
    let resource: FHIRResource?
}
struct FHIRResource: Decodable {
    let resourceType: String?
    // Coverage
    let payor:      [FHIRReference]?
    let `class`:    [FHIRClass]?
    let identifier: [FHIRIdentifier]?
    // EOB
    let total:          [FHIREOBTotal]?
    let billablePeriod: FHIRPeriod?
}
struct FHIRReference: Decodable   { let display: String? }
struct FHIRClass: Decodable       { let type: FHIRCodeableConcept?; let name: String? }
struct FHIRIdentifier: Decodable  { let type: FHIRCodeableConcept?; let value: String? }
struct FHIRCodeableConcept: Decodable { let coding: [FHIRCoding]? }
struct FHIRCoding: Decodable      { let code: String?; let display: String? }
struct FHIREOBTotal: Decodable    { let category: FHIRCodeableConcept?; let amount: FHIRMoney? }
struct FHIRMoney: Decodable       { let value: Double? }
struct FHIRPeriod: Decodable      { let start: String?; let end: String? }

struct EOBSummary {
    let date: String
    let totalBilled: Double?
    let patientOwes: Double?
}

// MARK: - Errors

enum FHIRError: LocalizedError {
    case authCancelled, notAuthenticated, badURL, badCallback, tokenExchangeFailed, httpError(Int)
    var errorDescription: String? {
        switch self {
        case .authCancelled:       return nil
        case .notAuthenticated:    return "Not connected to MyChart."
        case .badURL:              return "Invalid FHIR endpoint URL."
        case .badCallback:         return "Could not read the authorization response."
        case .tokenExchangeFailed: return "Token exchange failed."
        case .httpError(let c):    return "Server returned HTTP \(c)."
        }
    }
}

// MARK: - Data extension for base64url

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
