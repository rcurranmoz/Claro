import Foundation
import Observation
import SwiftUI

@Observable
final class DocumentStore {
    var documents: [HealthDocument] = []
    var insuranceProfile: InsuranceProfile?

    private let documentsKey = "claro.documents"
    private let insuranceKey = "claro.insurance"

    init() { load() }

    func addDocument(_ document: HealthDocument) {
        documents.insert(document, at: 0)
        persist()
        Task { await analyzeDocument(documentId: document.id) }
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

    func saveInsurance(_ profile: InsuranceProfile) {
        insuranceProfile = profile
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: documentsKey)
        }
        if let profile = insuranceProfile,
           let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: insuranceKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: documentsKey),
           let decoded = try? JSONDecoder().decode([HealthDocument].self, from: data) {
            documents = decoded
        }
        if let data = UserDefaults.standard.data(forKey: insuranceKey),
           let decoded = try? JSONDecoder().decode(InsuranceProfile.self, from: data) {
            insuranceProfile = decoded
        }
    }
}
