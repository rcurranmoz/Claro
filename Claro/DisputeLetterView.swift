import SwiftUI

struct DisputeLetterView: View {
    let document: HealthDocument
    let issues: [FlaggedIssue]
    @Environment(\.dismiss) private var dismiss
    @State private var letterText  = ""
    @State private var isGenerating = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.claroBackground.ignoresSafeArea()

                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView().tint(Color.claroAccent)
                            .scaleEffect(1.2)
                        Text("Drafting your dispute letter…")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.claroSubtle)
                    }
                } else if let err = errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.claroWarning)
                        Text("Couldn't generate letter")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.claroSubtle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Try Again") { generate() }
                            .foregroundStyle(Color.claroAccent)
                            .padding(.top, 4)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Instruction banner
                            HStack(spacing: 10) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.claroWarning)
                                Text("Fill in the [BRACKETED] placeholders before sending.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.claroSubtle)
                            }
                            .padding(14)
                            .background(Color.claroWarning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.claroWarning.opacity(0.25), lineWidth: 1))
                            .padding(.horizontal, 20)

                            // Letter
                            Text(letterText)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .lineSpacing(5)
                                .padding(20)
                                .background(Color.claroSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Dispute Letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.claroSubtle)
                }
                if !letterText.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: letterText) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.claroAccent)
                        }
                    }
                }
            }
        }
        .task { generate() }
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                letterText = try await AnalysisService.shared.generateDisputeLetter(
                    for: document, issues: issues
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
