import SwiftUI
import UIKit
import AuthenticationServices

struct InsuranceSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DocumentStore.self) private var store

    @State private var insurerName = ""
    @State private var planName = ""
    @State private var memberId = ""
    @State private var deductible = ""
    @State private var deductibleMet = ""
    @State private var outOfPocketMax = ""
    @State private var outOfPocketMet = ""
    @Environment(FHIRService.self) private var fhir
    @State private var showingCardScanner = false
    @State private var isExtracting = false
    @State private var extractionError: String?
    @State private var isImportingFHIR = false

    private var canSave: Bool {
        !insurerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    mycartButton
                    scanCardButton
                } footer: {
                    Text("Connect MyChart to auto-fill your plan details, or scan your insurance card.")
                }

                Section("Plan") {
                    TextField("Insurance Company", text: $insurerName)
                    TextField("Plan Name (e.g. PPO Gold)", text: $planName)
                    TextField("Member ID", text: $memberId)
                }

                Section {
                    TextField("Annual Deductible", text: $deductible)
                        .keyboardType(.decimalPad)
                    TextField("Deductible Met This Year", text: $deductibleMet)
                        .keyboardType(.decimalPad)
                    TextField("Out-of-Pocket Maximum", text: $outOfPocketMax)
                        .keyboardType(.decimalPad)
                    TextField("Out-of-Pocket Met This Year", text: $outOfPocketMet)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Cost Sharing")
                } footer: {
                    Text("Deductible and out-of-pocket amounts are on your EOB or member portal.")
                }
            }
            .navigationTitle(store.insuranceProfile == nil ? "Add Insurance" : "Edit Insurance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
            .alert("Couldn't Read Card", isPresented: .constant(extractionError != nil)) {
                Button("OK") { extractionError = nil }
            } message: {
                Text(extractionError ?? "")
            }
        }
        .sheet(isPresented: $showingCardScanner) {
            DocumentCamera(
                onScan: { images in
                    showingCardScanner = false
                    if let image = images.first { extractCard(from: image) }
                },
                onCancel: { showingCardScanner = false }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - MyChart Connect Button

    private var mycartButton: some View {
        Button {
            Task { await connectMyChart() }
        } label: {
            HStack(spacing: 12) {
                if fhir.isAuthenticating || isImportingFHIR {
                    ProgressView()
                } else {
                    Image(systemName: fhir.isConnected ? "cross.circle.fill" : "cross.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(fhir.isConnected ? Color.claroAccent : Color.cyan)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(fhir.isConnected
                         ? (isImportingFHIR ? "Importing from MyChart…" : "MyChart Connected")
                         : "Connect MyChart")
                        .font(.system(size: 15, weight: .medium))
                    Text(fhir.isConnected
                         ? "Tap to re-import your coverage details"
                         : "Auto-fill from Epic, Kaiser, CommonSpirit & more")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if fhir.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.claroAccent)
                }
            }
        }
        .disabled(fhir.isAuthenticating || isImportingFHIR)
    }

    private func connectMyChart() async {
        if !fhir.isConnected {
            await fhir.authenticate(presentingWindow: ASPresentationAnchor())
        }
        guard fhir.isConnected else { return }
        isImportingFHIR = true
        do {
            if let profile = try await fhir.fetchCoverage() {
                insurerName    = profile.insurerName
                planName       = profile.planName
                memberId       = profile.memberId
            }
        } catch {
            extractionError = error.localizedDescription
        }
        isImportingFHIR = false
    }

    // MARK: - Scan Card Button

    private var scanCardButton: some View {
        Button {
            showingCardScanner = true
        } label: {
            HStack(spacing: 12) {
                if isExtracting {
                    ProgressView()
                } else {
                    Image(systemName: "creditcard.viewfinder")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.claroAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isExtracting ? "Reading card…" : "Scan Insurance Card")
                        .font(.system(size: 15, weight: .medium))
                    if !isExtracting {
                        Text("Auto-fill from your physical card")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .disabled(isExtracting)
    }

    // MARK: - Card Extraction

    private func extractCard(from image: UIImage) {
        isExtracting = true
        Task {
            do {
                let info = try await AnalysisService.shared.extractInsuranceCard(image: image)
                if !info.insurerName.isEmpty { insurerName = info.insurerName }
                if !info.planName.isEmpty    { planName    = info.planName    }
                if !info.memberId.isEmpty    { memberId    = info.memberId    }
            } catch {
                extractionError = error.localizedDescription
            }
            isExtracting = false
        }
    }

    // MARK: - Helpers

    private func prefill() {
        guard let p = store.insuranceProfile else { return }
        insurerName = p.insurerName
        planName = p.planName
        memberId = p.memberId
        deductible    = p.deductibleAnnual > 0 ? String(Int(p.deductibleAnnual)) : ""
        deductibleMet = p.deductibleMet    > 0 ? String(Int(p.deductibleMet))    : ""
        outOfPocketMax = p.outOfPocketMax  > 0 ? String(Int(p.outOfPocketMax))   : ""
        outOfPocketMet = p.outOfPocketMet  > 0 ? String(Int(p.outOfPocketMet))   : ""
    }

    private func save() {
        store.saveInsurance(InsuranceProfile(
            insurerName: insurerName,
            planName: planName,
            memberId: memberId,
            deductibleAnnual: Double(deductible)    ?? 0,
            deductibleMet:    Double(deductibleMet)  ?? 0,
            outOfPocketMax:   Double(outOfPocketMax) ?? 0,
            outOfPocketMet:   Double(outOfPocketMet) ?? 0
        ))
        dismiss()
    }
}
