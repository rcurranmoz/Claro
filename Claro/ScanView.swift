import SwiftUI
import VisionKit
import UIKit

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DocumentStore.self) private var store

    @State private var scannedImages: [UIImage]
    @State private var selectedType: DocumentType = .medicalBill
    @State private var isSaving = false

    init(preloadedImages: [UIImage] = []) {
        _scannedImages = State(initialValue: preloadedImages)
    }

    var body: some View {
        if scannedImages.isEmpty {
            DocumentCamera(onScan: { scannedImages = $0 }, onCancel: { dismiss() })
                .ignoresSafeArea()
        } else {
            reviewView
        }
    }

    private var reviewView: some View {
        NavigationStack {
            ZStack {
                Color.claroBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if let image = scannedImages.first {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    Text(scannedImages.count == 1 ? "1 page scanned" : "\(scannedImages.count) pages scanned")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.claroSubtle)
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What type of document is this?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DocumentType.allCases, id: \.self) { type in
                                    TypeChip(type: type, isSelected: selectedType == type) {
                                        selectedType = type
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 28)

                    Spacer()

                    Button {
                        save()
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.black) }
                            Text(isSaving ? "Saving..." : "Save Document")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.claroAccent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Retake") { scannedImages = [] }
                        .foregroundStyle(Color.claroAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.claroSubtle)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let imageData = scannedImages.first?.jpegData(compressionQuality: 0.85)
        var document = HealthDocument(type: selectedType, imageData: imageData)
        document.title = selectedType.rawValue
        store.addDocument(document)
        dismiss()
    }
}

// MARK: - Type Chip

private struct TypeChip: View {
    let type: DocumentType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.systemImage).font(.system(size: 12))
                Text(type.rawValue).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(isSelected ? Color.claroAccent : Color.claroSurface)
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Document Camera (VisionKit)

struct DocumentCamera: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onCancel: onCancel) }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan; self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onScan((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onCancel() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onCancel() }
    }
}
