//
//  NativeCameraPhotoLibrarySaver.swift
//  AniMagic
//
//  Created by MorpKnight on 20/07/26.
//

import Photos
import UIKit

enum NativeCameraPhotoLibrarySaver {
    static func savePhoto(_ image: UIImage) async throws {
        let authorizationStatus = await requestAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw NativeCameraPhotoLibraryError.accessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NativeCameraPhotoLibraryError.saveFailed)
                }
            }
        }
    }

    static func save(_ media: NativeCameraCapturedMedia) async throws {
        let authorizationStatus = await requestAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw NativeCameraPhotoLibraryError.accessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                switch media.kind {
                case .photo:
                    _ = PHAssetChangeRequest.creationRequestForAssetFromImage(
                        atFileURL: media.fileURL
                    )
                case .video:
                    _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(
                        atFileURL: media.fileURL
                    )
                }
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NativeCameraPhotoLibraryError.saveFailed)
                }
            }
        }
    }

    private static func requestAuthorization() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}

private enum NativeCameraPhotoLibraryError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Photos access is needed to save this capture. Enable access in Settings, then try again."
        case .saveFailed:
            "The capture could not be saved to Photos."
        }
    }
}
