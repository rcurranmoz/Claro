import SwiftUI
import UIKit

struct DocumentDetailView: View {
    let documentId: UUID
    @Environment(DocumentStore.self) private var store
    @State private var errorMessage: String?

    private var document: HealthDocument? {
        store.documents.first { $0.id == documentId }
    }

    var body: some View {
        ZStack {
            Color.claroBackground.ignoresSafeArea()
            if let doc = document {
                if let analysis = doc.analysis {
                    analysisView(analysis, doc: doc)
                } else {
                    pendingView
                }
            }
        }
        .navigationTitle(document?.title ?? "Document")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Fallback: trigger analysis if it somehow wasn't started on save
            await store.analyzeDocument(documentId: documentId)
        }
    }

    // MARK: - Analysis View

    private func analysisView(_ analysis: DocumentAnalysis, doc: HealthDocument) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Scanned image
                if let imageData = doc.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                }

                // Score banner
                scoreBanner(analysis)

                // Summary
                CardSection(title: "Summary") {
                    Text(analysis.summary)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineSpacing(4)
                }

                // Financial summary
                if analysis.totalBilled != nil || analysis.patientOwes != nil {
                    CardSection(title: "Financial Summary") {
                        VStack(spacing: 10) {
                            if let total = analysis.totalBilled {
                                AmountRow(label: "Total Billed", amount: total, isBold: false)
                            }
                            if let owes = analysis.patientOwes {
                                AmountRow(label: "You Owe", amount: owes, isBold: true)
                            }
                        }
                    }
                }

                // Red alerts
                let alerts = analysis.flaggedIssues.filter { $0.severity == .alert }
                if !alerts.isEmpty {
                    CardSection(title: "🔴  Needs Attention") {
                        VStack(spacing: 10) {
                            ForEach(alerts) { issue in IssueRow(issue: issue) }
                        }
                    }
                }

                // Yellow warnings
                let warnings = analysis.flaggedIssues.filter { $0.severity == .warning }
                if !warnings.isEmpty {
                    CardSection(title: "🟡  Worth Checking") {
                        VStack(spacing: 10) {
                            ForEach(warnings) { issue in IssueRow(issue: issue) }
                        }
                    }
                }

                // Green positives
                let positives = analysis.positiveFindings
                let infoIssues = analysis.flaggedIssues.filter { $0.severity == .info }
                if !positives.isEmpty || !infoIssues.isEmpty {
                    CardSection(title: "🟢  Looks Good") {
                        VStack(spacing: 10) {
                            ForEach(positives) { finding in PositiveRow(finding: finding) }
                            ForEach(infoIssues) { issue in IssueRow(issue: issue) }
                        }
                    }
                }

                // Action items
                if !analysis.actionItems.isEmpty {
                    CardSection(title: "Action Items") {
                        VStack(spacing: 12) {
                            ForEach(analysis.actionItems) { item in ActionRow(item: item) }
                        }
                    }
                }

                // Line items
                if !analysis.lineItems.isEmpty {
                    CardSection(title: "Line by Line") {
                        VStack(spacing: 14) {
                            ForEach(analysis.lineItems) { item in LineItemRow(item: item) }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Score Banner

    private func scoreBanner(_ analysis: DocumentAnalysis) -> some View {
        let alertCount   = analysis.flaggedIssues.filter { $0.severity == .alert   }.count
        let warningCount = analysis.flaggedIssues.filter { $0.severity == .warning }.count
        let greenCount   = analysis.positiveFindings.count +
                           analysis.flaggedIssues.filter { $0.severity == .info }.count

        return HStack(spacing: 0) {
            ScoreChip(count: greenCount,   label: "Good",   color: .claroAccent,  icon: "checkmark.circle.fill")
            Divider().frame(height: 32).background(Color.white.opacity(0.08))
            ScoreChip(count: warningCount, label: "Review", color: .claroWarning, icon: "exclamationmark.circle.fill")
            Divider().frame(height: 32).background(Color.white.opacity(0.08))
            ScoreChip(count: alertCount,   label: "Alert",  color: .claroDanger,  icon: "xmark.circle.fill")
        }
        .padding(.vertical, 14)
        .background(Color.claroSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Pending View

    private var pendingView: some View {
        VStack(spacing: 20) {
            Spacer()
            if let imageData = document?.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 8) {
                ProgressView().tint(Color.claroAccent)
                Text("Analyzing document…")
                    .font(.subheadline)
                    .foregroundStyle(Color.claroSubtle)
            }
            Spacer()
        }
    }
}

// MARK: - Score Chip

private struct ScoreChip: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(count > 0 ? color : Color.claroSubtle)
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(count > 0 ? color : Color.claroSubtle)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.claroSubtle)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Card Section

struct CardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.claroSubtle)
                .textCase(.uppercase)
                .tracking(0.8)
            content
        }
        .padding(18)
        .background(Color.claroSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - Sub-rows

private struct AmountRow: View {
    let label: String
    let amount: Double
    let isBold: Bool
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: isBold ? .semibold : .regular))
                .foregroundStyle(isBold ? Color.white : Color.claroSubtle)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.system(size: 14, weight: isBold ? .semibold : .regular))
                .foregroundStyle(isBold ? Color.claroAccent : Color.claroSubtle)
        }
    }
}

private struct IssueRow: View {
    let issue: FlaggedIssue

    var severityColor: Color {
        switch issue.severity {
        case .alert:   return .claroDanger
        case .warning: return .claroWarning
        case .info:    return .claroAccent
        }
    }
    var severityIcon: String {
        switch issue.severity {
        case .alert:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: severityIcon)
                .font(.system(size: 14))
                .foregroundStyle(severityColor)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(issue.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.claroSubtle)
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .background(severityColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(severityColor.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct PositiveRow: View {
    let finding: PositiveFinding
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.claroAccent)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(finding.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.claroSubtle)
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .background(Color.claroAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.claroAccent.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct ActionRow: View {
    let item: ActionItem
    var urgencyColor: Color {
        switch item.urgency {
        case .high:   return .claroDanger
        case .medium: return .claroWarning
        case .low:    return .claroAccent
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(urgencyColor)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(item.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.claroSubtle)
                    .lineSpacing(3)
            }
        }
    }
}

private struct LineItemRow: View {
    let item: LineItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let code = item.code {
                        Text(code)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.claroSubtle)
                    }
                    Text(item.plainDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer()
                if let amount = item.amount {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.claroAccent)
                }
            }
            if item.rawDescription != item.plainDescription {
                Text(item.rawDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.claroSubtle.opacity(0.6))
            }
        }
    }
}
