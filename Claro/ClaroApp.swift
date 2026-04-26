//
//  ClaroApp.swift
//  Claro
//
//  Created by Ryan Curran on 4/26/26.
//

import SwiftUI

@main
struct ClaroApp: App {
    @State private var store = DocumentStore()
    @State private var auth  = AuthService()
    private let fhir = FHIRService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(fhir)
                .environment(auth)
                .preferredColorScheme(.dark)
        }
    }
}
