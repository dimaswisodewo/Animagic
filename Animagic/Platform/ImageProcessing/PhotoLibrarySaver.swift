//
//  PhotoLibrarySaver.swift
//  AniMagic
//
//  Created by dimaswisodewo on 26/07/26.
//

import UIKit

final class PhotoLibrarySaver: NSObject {
    private let onSuccess: () -> Void

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }

    func save(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc private func saveCompleted(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer
    ) {
        guard error == nil else { return }
        onSuccess()
    }
}
