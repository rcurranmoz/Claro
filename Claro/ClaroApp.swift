//
//  ClaroApp.swift
//  Claro
//
//  Created by Ryan Curran on 4/26/26.
//

import SwiftUI
import RevenueCat

@main
struct ClaroApp: App {
    @State private var store         = DocumentStore()
    @State private var auth          = AuthService()
    @State private var subscriptions = SubscriptionService()
    private let fhir = FHIRService.shared

    init() {
        let userId = UserDefaults.standard.string(forKey: "claro.auth.userId")
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey, appUserID: userId)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(fhir)
                .environment(auth)
                .environment(subscriptions)
                .preferredColorScheme(.dark)
                .task { await subscriptions.load() }
        }
    }
}
