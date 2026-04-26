import SwiftUI
import UIKit
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Upload Flow (single sheet: picker → review)

enum UploadSource { case photos, files }

struct UploadFlowView: View {
    let source: UploadSource
    @Environment(\.dismiss) private var dismiss
    @State private var pickedImages: [UIImage] = []

    var body: some View {
        if pickedImages.isEmpty {
            switch source {
            case .photos:
                PhotoLibraryPicker(
                    onPick: { pickedImages = $0 },
                    onCancel: { dismiss() }
                )
            case .files:
                DocumentFilePicker(
                    onPick: { pickedImages = $0 },
                    onCancel: { dismiss() }
                )
            }
        } else {
            ScanView(preloadedImages: pickedImages)
        }
    }
}

// MARK: - Photo Library Picker

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPick: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 10
        config.filter = .images
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick; self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else { onCancel(); return }
            var images: [UIImage] = []
            let group = DispatchGroup()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage { images.append(img) }
                    group.leave()
                }
            }
            group.notify(queue: .main) { [self] in
                if images.isEmpty { onCancel() } else { onPick(images) }
            }
        }
    }
}

// MARK: - File Picker (PDFs + images)
// Uses a transparent container VC so UIDocumentPickerViewController's auto-dismiss
// doesn't collapse the SwiftUI sheet — the sheet stays alive for the review transition.

struct DocumentFilePicker: UIViewControllerRepresentable {
    let onPick: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        return container
    }

    func updateUIViewController(_ container: UIViewController, context: Context) {
        guard !context.coordinator.hasPresented else { return }
        context.coordinator.hasPresented = true
        DispatchQueue.main.async {
            let types: [UTType] = [.pdf, .image, .jpeg, .png, .heic]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            container.present(picker, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([UIImage]) -> Void
        let onCancel: () -> Void
        var hasPresented = false

        init(onPick: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick; self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { onCancel(); return }
            let images = imagesFrom(url: url)
            DispatchQueue.main.async {
                if images.isEmpty { self.onCancel() } else { self.onPick(images) }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onCancel() }

        private func imagesFrom(url: URL) -> [UIImage] {
            if url.pathExtension.lowercased() == "pdf" {
                guard let doc = PDFDocument(url: url) else { return [] }
                return (0..<min(doc.pageCount, 20)).compactMap { i in
                    guard let page = doc.page(at: i) else { return nil }
                    let bounds = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 2.0
                    let renderer = UIGraphicsImageRenderer(
                        size: CGSize(width: bounds.width * scale, height: bounds.height * scale))
                    return renderer.image { ctx in
                        let cgCtx = ctx.cgContext
                        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                        cgCtx.setFillColor(UIColor.white.cgColor)
                        cgCtx.fill(CGRect(origin: .zero, size: renderSize))
                        cgCtx.translateBy(x: 0, y: renderSize.height)
                        cgCtx.scaleBy(x: scale, y: -scale)
                        page.draw(with: .mediaBox, to: cgCtx)
                    }
                }
            } else {
                return UIImage(contentsOfFile: url.path).map { [$0] } ?? []
            }
        }
    }
}
