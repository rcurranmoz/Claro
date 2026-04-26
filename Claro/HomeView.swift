import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(DocumentStore.self) private var store
    @State private var showingScanner = false
    @State private var showingInsuranceSetup = false
    @State private var showingUploadChoice = false
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var uploadedImages: [UIImage] = []
    @State private var showingScanReview = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        insuranceSection
                        scanButton
                        if !store.documents.isEmpty {
                            documentsSection
                        } else {
                            emptyHint
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Claro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingInsuranceSetup = true } label: {
                        Image(systemName: store.insuranceProfile == nil
                              ? "person.crop.circle.badge.plus"
                              : "person.crop.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(store.insuranceProfile == nil
                                             ? Color.claroSubtle : Color.claroAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingScanner) { ScanView() }
        .sheet(isPresented: $showingScanReview, onDismiss: {
            uploadedImages = []
        }) {
            ScanView(preloadedImages: uploadedImages)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryPicker(
                onPick: { images in
                    uploadedImages = images
                    showingPhotoPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        showingScanReview = true
                    }
                },
                onCancel: { showingPhotoPicker = false }
            )
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentFilePicker(
                onPick: { images in
                    uploadedImages = images
                    showingFilePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        showingScanReview = true
                    }
                },
                onCancel: { showingFilePicker = false }
            )
        }
        .sheet(isPresented: $showingInsuranceSetup) { InsuranceSetupView() }
        .confirmationDialog("Add Document", isPresented: $showingUploadChoice, titleVisibility: .visible) {
            Button("Scan with Camera") { showingScanner = true }
            Button("Choose from Photos") { showingPhotoPicker = true }
            Button("Import from Files") { showingFilePicker = true }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var insuranceSection: some View {
        if let profile = store.insuranceProfile {
            InsuranceCard(profile: profile) { showingInsuranceSetup = true }
        } else {
            InsurancePrompt { showingInsuranceSetup = true }
        }
    }

    private var scanButton: some View {
        Button { showingUploadChoice = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.claroAccent.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.claroAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scan a Document")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Bill, EOB, lab results, insurance card")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.claroSubtle)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.claroAccent)
            }
            .padding(18)
            .background(Color.claroSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color.claroAccent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.claroSubtle)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(store.documents) { document in
                NavigationLink(destination: DocumentDetailView(documentId: document.id)) {
                    DocumentRow(document: document)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(Color.claroSubtle.opacity(0.4))
            Text("Scan your first document to get started")
                .font(.system(size: 14))
                .foregroundStyle(Color.claroSubtle)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
    }
}

// MARK: - Insurance Card

private struct InsuranceCard: View {
    let profile: InsuranceProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.insurerName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        if !profile.planName.isEmpty {
                            Text(profile.planName)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.claroSubtle)
                        }
                    }
                    Spacer()
                    Image(systemName: "shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.claroAccent)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)

                VStack(spacing: 12) {
                    CostBar(label: "Deductible",
                            current: profile.deductibleMet,
                            total: profile.deductibleAnnual,
                            progress: profile.deductibleProgress,
                            color: .claroAccent)
                    CostBar(label: "Out-of-Pocket Max",
                            current: profile.outOfPocketMet,
                            total: profile.outOfPocketMax,
                            progress: profile.outOfPocketProgress,
                            color: .cyan)
                }
            }
            .padding(20)
            .background(Color.claroSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct CostBar: View {
    let label: String
    let current: Double
    let total: Double
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.claroSubtle)
                Spacer()
                Text("$\(Int(current)) of $\(Int(total))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: geo.size.width * max(progress, 0.02))
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Insurance Prompt

private struct InsurancePrompt: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.claroAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your insurance plan")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Track your deductible and out-of-pocket costs")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.claroSubtle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.claroSubtle)
            }
            .padding(18)
            .background(Color.claroSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: HealthDocument

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(document.type.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: document.type.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(document.type.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Text(document.dateScanned.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.claroSubtle)
            }
            Spacer()
            if document.analysis == nil {
                Text("Pending")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.claroWarning.opacity(0.15))
                    .foregroundStyle(Color.claroWarning)
                    .clipShape(Capsule())
            } else if !(document.analysis?.flaggedIssues.isEmpty ?? true) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.claroWarning)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.claroAccent)
            }
        }
        .padding(16)
        .background(Color.claroSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    HomeView()
        .environment(DocumentStore())
}
