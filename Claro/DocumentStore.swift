import Foundation
import Observation
import SwiftUI
import UserNotifications

@Observable
final class DocumentStore {
    var documents: [HealthDocument] = []
    var insuranceProfile: InsuranceProfile?
    var profiles: [Profile] = []
    var activeProfileId: UUID? = nil  // nil = "Me" (default)

    // MARK: - Computed

    var activeDocuments: [HealthDocument] {
        documents.filter { $0.profileId == activeProfileId }
    }

    var totalBilledThisYear: Double {
        let year = Calendar.current.component(.year, from: Date())
        return activeDocuments
            .filter { Calendar.current.component(.year, from: $0.dateScanned) == year }
            .compactMap { $0.analysis?.totalBilled }
            .reduce(0, +)
    }

    var totalOwedThisYear: Double {
        let year = Calendar.current.component(.year, from: Date())
        return activeDocuments
            .filter { Calendar.current.component(.year, from: $0.dateScanned) == year }
            .compactMap { $0.analysis?.patientOwes }
            .reduce(0, +)
    }

    // MARK: - Init

    init() {
        migrateFromUserDefaultsIfNeeded()
        load()
    }

    // MARK: - Document Operations

    func addDocument(_ document: HealthDocument) {
        var doc = document
        doc.profileId = activeProfileId
        documents.insert(doc, at: 0)
        persist()
        requestNotificationPermissionIfNeeded()
        Task { await analyzeDocument(documentId: doc.id) }
    }

    func analyzeDocument(documentId: UUID) async {
        guard let doc = documents.first(where: { $0.id == documentId }),
              doc.analysis == nil else { return }
        do {
            let analysis = try await AnalysisService.shared.analyze(document: doc)
            var updated = doc
            updated.analysis = analysis
            if !analysis.title.isEmpty { updated.title = analysis.title }
            updateDocument(updated)
            sendAnalysisNotification(for: updated)
        } catch {
            // Analysis errors surface in DocumentDetailView via its own retry path
        }
    }

    func updateDocument(_ document: HealthDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
        persist()
    }

    func deleteDocuments(at offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
        persist()
    }

    func deleteDocument(id: UUID) {
        documents.removeAll { $0.id == id }
        persist()
    }

    func saveInsurance(_ profile: InsuranceProfile) {
        insuranceProfile = profile
        persist()
    }

    // MARK: - Profile Operations

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        persist()
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfileId == profile.id { activeProfileId = nil }
        persist()
    }

    // MARK: - Notifications

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendAnalysisNotification(for document: HealthDocument) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Analysis Ready"
            content.body = "\(document.title) has been reviewed."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: document.id.uuidString,
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Persistence (FileManager)

    private var storageDir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ClaroData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func persist() {
        let enc = JSONEncoder()
        try? enc.encode(documents).write(to: storageDir.appendingPathComponent("documents.json"))
        if let profile = insuranceProfile {
            try? enc.encode(profile).write(to: storageDir.appendingPathComponent("insurance.json"))
        }
        try? enc.encode(profiles).write(to: storageDir.appendingPathComponent("profiles.json"))
    }

    private func load() {
        let dec = JSONDecoder()
        if let data = try? Data(contentsOf: storageDir.appendingPathComponent("documents.json")),
           let decoded = try? dec.decode([HealthDocument].self, from: data) {
            documents = decoded
        }
        if let data = try? Data(contentsOf: storageDir.appendingPathComponent("insurance.json")),
           let decoded = try? dec.decode(InsuranceProfile.self, from: data) {
            insuranceProfile = decoded
        }
        if let data = try? Data(contentsOf: storageDir.appendingPathComponent("profiles.json")),
           let decoded = try? dec.decode([Profile].self, from: data) {
            profiles = decoded
        }
    }

    private func migrateFromUserDefaultsIfNeeded() {
        let key = "claro.migrated.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let dec = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "claro.documents"),
           let decoded = try? dec.decode([HealthDocument].self, from: data) {
            documents = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "claro.insurance"),
           let decoded = try? dec.decode(InsuranceProfile.self, from: data) {
            insuranceProfile = decoded
        }
        UserDefaults.standard.set(true, forKey: key)
        persist()
    }
}
