// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import PhotosUI

/// Standard iOS photo picker, available from iOS 14. No photo-library
/// entitlement or broad library access is needed.
struct BloomBoxNovaWallpaperPicker: UIViewControllerRepresentable {
    let onChoose: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChoose: onChoose)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onChoose: (UIImage) -> Void

        init(onChoose: @escaping (UIImage) -> Void) {
            self.onChoose = onChoose
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            _ = provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self?.onChoose(image) }
            }
        }
    }
}
