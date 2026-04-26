import SwiftUI
import UIKit

    private enum Sheet: Identifiable {
        case scanner, photoPicker, filePicker, insuranceSetup, settings
        var id: String { "\(self)" }
    }

struct HomeView: View {
    @Environment(DocumentStore.self) private var store
    @State private var activeSheet: Sheet?
    @State private var showingUploadChoice = false
    @State private var searchText = ""

    private var filteredDocuments: [HealthDocument] {
        guard !searchText.isEmpty else { return store.activeDocuments }
        return store.activeDocuments.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.type.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var isEmptyFamilyProfile: Bool {
        store.activeProfileId != nil && filteredDocuments.isEmpty && searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if !store.profiles.isEmpty { profileSwitcher }

                        if isEmptyFamilyProfile {
                            scanButton
                                .padding(.top, 220)
                        } else {
                            if store.activeProfileId == nil { insuranceSection }
                            if store.activeProfileId == nil { spendingCard }
                            scanButton
                            if !filteredDocuments.isEmpty {
                                documentsSection
                            } else if searchText.isEmpty {
                                emptyHint
                            } else {
                                noResultsHint
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Claro Lens")
            .searchable(text: $searchText, prompt: "Search documents")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { activeSheet = .settings } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.claroSubtle)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { activeSheet = .insuranceSetup } label: {
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .scanner:
                ScanView()
            case .photoPicker:
                UploadFlowView(source: .photos)
            case .filePicker:
                UploadFlowView(source: .files)
            case .insuranceSetup:
                InsuranceSetupView()
            case .settings:
                SettingsView()
            }
        }
        .confirmationDialog("Add Document", isPresented: $showingUploadChoice, titleVisibility: .visible) {
            Button("Scan with Camera") { activeSheet = .scanner }
            Button("Choose from Photos") { activeSheet = .photoPicker }
            Button("Import from Files") { activeSheet = .filePicker }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var insuranceSection: some View {
        if let profile = store.insuranceProfile {
            InsuranceCard(profile: profile) { activeSheet = .insuranceSetup }
        } else {
            InsurancePrompt { activeSheet = .insuranceSetup }
        }
    }

    private var profileSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ProfileChip(
                    name: "Me", icon: "person.fill", color: .claroAccent,
                    isActive: store.activeProfileId == nil
                ) { store.activeProfileId = nil }

                ForEach(store.profiles) { profile in
                    ProfileChip(
                        name: profile.name,
                        icon: profile.relationship.systemImage,
                        color: profile.relationship.color,
                        isActive: store.activeProfileId == profile.id
                    ) { store.activeProfileId = profile.id }
                }
            }
        }
        .padding(.horizontal, -20)  // bleed past section padding
        .padding(.leading, 20)
    }

    private var spendingCard: some View {
        NavigationLink(destination: SpendingView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.claroWarning.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.claroWarning)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("This Year's Spending")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    let owed = store.totalOwedThisYear
                    if owed > 0 {
                        (Text(owed, format: .currency(code: "USD"))
                            .foregroundStyle(Color.claroWarning)
                        + Text(" patient responsibility")
                            .foregroundStyle(Color.claroSubtle))
                        .font(.system(size: 13))
                    } else {
                        Text("Tap to view your spending summary")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.claroSubtle)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.claroSubtle)
            }
            .padding(16)
            .background(Color.claroSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
            Text(searchText.isEmpty ? "Recent" : "Results")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.claroSubtle)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(filteredDocuments) { document in
                NavigationLink(destination: DocumentDetailView(documentId: document.id)) {
                    DocumentRow(document: document)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        store.deleteDocument(id: document.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
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

    private var noResultsHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(Color.claroSubtle.opacity(0.4))
            Text("No results for \"\(searchText)\"")
                .font(.system(size: 14))
                .foregroundStyle(Color.claroSubtle)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
    }
}

// MARK: - Profile Chip

private struct ProfileChip: View {
    let name: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(name).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isActive ? color : Color.claroSurface)
            .foregroundStyle(isActive ? .black : color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? Color.clear : color.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                    .lineLimit(1)
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
            } else if document.analysis?.flaggedIssues.contains(where: { $0.severity == .alert }) == true {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.claroDanger)
            } else if document.analysis?.flaggedIssues.contains(where: { $0.severity == .warning }) == true {
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
