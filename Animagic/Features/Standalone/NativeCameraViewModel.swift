//
//  NativeCameraViewModel.swift
//  AniMagic
//
//  Created by MorpKnight on 20/07/26.
//

import AVFoundation
import Combine
import Foundation
import UIKit

enum NativeCameraAuthorizationState: Equatable {
    case checking
    case authorized
    case denied(String)
}

enum NativeCameraMediaKind: Equatable {
    case photo
    case video
}

struct NativeCameraCapturedMedia: Identifiable {
    let id = UUID()
    let kind: NativeCameraMediaKind
    let fileURL: URL
    let previewImage: UIImage
}

@MainActor
final class NativeCameraViewModel: NSObject, ObservableObject {
    // These AVFoundation objects are serialized through sessionQueue whenever they
    // are configured or started/stopped off the main actor.
    nonisolated(unsafe) let session = AVCaptureSession()

    @Published private(set) var authorizationState: NativeCameraAuthorizationState = .checking
    @Published private(set) var isConfigured = false
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var capturedMedia: NativeCameraCapturedMedia?
    @Published private(set) var latestThumbnail: UIImage?
    @Published private(set) var isShowingCaptureFlash = false
    @Published private(set) var isSaving = false
    @Published private(set) var feedbackMessage: String?
    @Published private(set) var errorMessage: String?

    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.diroudough.animagic.native-camera-session")

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var cameraDevice: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var captureRotationObservation: NSKeyValueObservation?
    private var photoDelegate: NativeCameraPhotoCaptureDelegate?
    private var movieDelegate: NativeCameraMovieRecordingDelegate?
    private var currentRecordingURL: URL?
    private var captureFlashTask: Task<Void, Never>?
    private var recordingTimerTask: Task<Void, Never>?
    private var isPreparing = false
    private var isViewActive = false

    var canCapture: Bool {
        authorizationState == .authorized
            && isConfigured
            && isSessionRunning
            && !isRecording
            && capturedMedia == nil
            && !isSaving
    }

    var formattedRecordingDuration: String {
        let totalSeconds = Int(recordingDuration)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    func start() {
        isViewActive = true
        guard !isPreparing else { return }

        if isConfigured {
            startSession()
            return
        }

        isPreparing = true
        errorMessage = nil
        authorizationState = .checking

        Task { [weak self] in
            guard let self else { return }

            guard await requestAccess(for: .video) else {
                authorizationState = .denied(
                    "Camera access is required to show the live preview. Enable it in Settings, then try again."
                )
                isPreparing = false
                return
            }

            guard await requestAccess(for: .audio) else {
                authorizationState = .denied(
                    "Microphone access is required to record video with audio. Enable it in Settings, then try again."
                )
                isPreparing = false
                return
            }

            configureSession()
        }
    }

    func stop() {
        isViewActive = false
        captureFlashTask?.cancel()
        captureFlashTask = nil
        stopRecordingTimer()
        isShowingCaptureFlash = false

        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }

        if let capturedMedia {
            removeTemporaryFile(at: capturedMedia.fileURL)
            self.capturedMedia = nil
        }

        stopSession()
    }

    func pauseSession() {
        if movieOutput.isRecording {
            stopRecording()
        }
        stopSession()
    }

    func resumeSession() {
        guard isViewActive, capturedMedia == nil else { return }
        startSession()
    }

    func configurePreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        updateRotationCoordinator()
    }

    func removePreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        guard previewLayer === layer else { return }
        previewRotationObservation?.invalidate()
        captureRotationObservation?.invalidate()
        previewRotationObservation = nil
        captureRotationObservation = nil
        previewLayer = nil
        rotationCoordinator = nil
    }

    func capturePhoto() {
        guard canCapture,
              let connection = photoOutput.connection(with: .video) else {
            return
        }

        applyCaptureRotation(to: connection)

        let settings = AVCapturePhotoSettings()
        // The supported maximum varies by device and active session configuration.
        // Asking for a higher level causes AVCapturePhotoOutput to throw an exception.
        settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
        if photoOutput.supportedFlashModes.contains(.off) {
            // The visual shutter flash is handled by SwiftUI. The hardware flash stays off
            // because this standalone camera has no flash-mode control.
            settings.flashMode = .off
        }

        let delegate = NativeCameraPhotoCaptureDelegate { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handlePhotoResult(result)
            }
        }
        photoDelegate = delegate
        triggerCaptureFeedback()
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    @discardableResult
    func beginRecording() -> Bool {
        guard canCapture,
              !movieOutput.isRecording,
              let connection = movieOutput.connection(with: .video) else {
            return false
        }

        applyCaptureRotation(to: connection)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("animagic-\(UUID().uuidString)", isDirectory: false)
            .appendingPathExtension("mov")

        let delegate = NativeCameraMovieRecordingDelegate { [weak self] url, error in
            Task { @MainActor [weak self] in
                self?.handleMovieResult(url: url, error: error)
            }
        }

        currentRecordingURL = outputURL
        movieDelegate = delegate
        movieOutput.startRecording(to: outputURL, recordingDelegate: delegate)
        isRecording = true
        startRecordingTimer()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        stopRecordingTimer()
        movieOutput.stopRecording()
    }

    func cancelReview() {
        guard let capturedMedia else { return }
        removeTemporaryFile(at: capturedMedia.fileURL)
        self.capturedMedia = nil
        errorMessage = nil
        resumeSession()
    }

    func confirmReview() {
        guard let capturedMedia, !isSaving else { return }

        isSaving = true
        errorMessage = nil

        Task { [weak self, capturedMedia] in
            do {
                try await NativeCameraPhotoLibrarySaver.save(capturedMedia)
                await MainActor.run {
                    guard let self else { return }
                    self.latestThumbnail = capturedMedia.previewImage
                    self.removeTemporaryFile(at: capturedMedia.fileURL)
                    self.capturedMedia = nil
                    self.isSaving = false
                    self.feedbackMessage = "Saved to Photos"
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.resumeSession()
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    func clearMessages() {
        errorMessage = nil
        feedbackMessage = nil
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestAccess(for mediaType: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: mediaType)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                guard let camera = Self.makeBackCamera() else {
                    throw NativeCameraError.cameraUnavailable
                }
                guard let microphone = AVCaptureDevice.default(for: .audio) else {
                    throw NativeCameraError.microphoneUnavailable
                }

                let newVideoInput = try AVCaptureDeviceInput(device: camera)
                let newAudioInput = try AVCaptureDeviceInput(device: microphone)

                self.session.beginConfiguration()
                defer { self.session.commitConfiguration() }

                if self.session.canSetSessionPreset(.high) {
                    self.session.sessionPreset = .high
                }

                guard self.session.canAddInput(newVideoInput) else {
                    throw NativeCameraError.inputUnavailable
                }
                self.session.addInput(newVideoInput)

                guard self.session.canAddInput(newAudioInput) else {
                    throw NativeCameraError.inputUnavailable
                }
                self.session.addInput(newAudioInput)

                guard self.session.canAddOutput(self.photoOutput) else {
                    throw NativeCameraError.photoOutputUnavailable
                }
                self.session.addOutput(self.photoOutput)

                guard self.session.canAddOutput(self.movieOutput) else {
                    throw NativeCameraError.movieOutputUnavailable
                }
                self.session.addOutput(self.movieOutput)

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    cameraDevice = camera
                    videoInput = newVideoInput
                    audioInput = newAudioInput
                    isConfigured = true
                    authorizationState = .authorized
                    isPreparing = false
                    updateRotationCoordinator()
                    startSession()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    isPreparing = false
                    errorMessage = error.localizedDescription
                    authorizationState = .denied(error.localizedDescription)
                }
            }
        }
    }

    private func startSession() {
        guard isConfigured, isViewActive else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !session.isRunning {
                session.startRunning()
            }
            let isRunning = session.isRunning
            DispatchQueue.main.async { [weak self] in
                self?.isSessionRunning = isRunning
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if session.isRunning {
                session.stopRunning()
            }
            DispatchQueue.main.async { [weak self] in
                self?.isSessionRunning = false
                self?.isRecording = false
            }
        }
    }

    private func updateRotationCoordinator() {
        guard let cameraDevice else { return }

        previewRotationObservation?.invalidate()
        captureRotationObservation?.invalidate()

        let coordinator = AVCaptureDevice.RotationCoordinator(
            device: cameraDevice,
            previewLayer: previewLayer
        )
        rotationCoordinator = coordinator

        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] _, change in
            let angle = change.newValue ?? 0
            Task { @MainActor [weak self] in
                self?.applyPreviewRotation(angle)
            }
        }

        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.initial, .new]
        ) { [weak self] _, change in
            let angle = change.newValue ?? 0
            Task { @MainActor [weak self] in
                self?.applyCaptureRotation(angle)
            }
        }

        applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        applyCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else {
            return
        }
        connection.videoRotationAngle = angle
    }

    private func applyCaptureRotation(to connection: AVCaptureConnection) {
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 0
        guard connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func applyCaptureRotation(_ angle: CGFloat) {
        let connections = [
            photoOutput.connection(with: .video),
            movieOutput.connection(with: .video)
        ]

        for connection in connections.compactMap({ $0 }) {
            guard connection.isVideoRotationAngleSupported(angle) else { continue }
            connection.videoRotationAngle = angle
        }
    }

    private func handlePhotoResult(_ result: Result<Data, Error>) {
        photoDelegate = nil

        do {
            let data = try result.get()
            guard let image = UIImage(data: data) else {
                throw NativeCameraError.photoDataUnavailable
            }

            let url = try makeTemporaryFile(data: data, fileExtension: "jpg")
            capturedMedia = NativeCameraCapturedMedia(
                kind: .photo,
                fileURL: url,
                previewImage: image
            )
            pauseSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleMovieResult(url: URL?, error: Error?) {
        stopRecordingTimer()
        isRecording = false
        movieDelegate = nil

        if let error {
            if let url { removeTemporaryFile(at: url) }
            currentRecordingURL = nil
            errorMessage = error.localizedDescription
            return
        }

        guard let url else {
            errorMessage = NativeCameraError.recordingUnavailable.localizedDescription
            return
        }

        currentRecordingURL = nil
        guard isViewActive else {
            removeTemporaryFile(at: url)
            return
        }

        sessionQueue.async { [weak self] in
            Self.makeVideoThumbnail(url: url) { thumbnail in
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        try? FileManager.default.removeItem(at: url)
                        return
                    }
                    guard isViewActive, let thumbnail else {
                        removeTemporaryFile(at: url)
                        errorMessage = NativeCameraError.videoThumbnailUnavailable.localizedDescription
                        return
                    }

                    capturedMedia = NativeCameraCapturedMedia(
                        kind: .video,
                        fileURL: url,
                        previewImage: thumbnail
                    )
                    pauseSession()
                }
            }
        }
    }

    private func triggerCaptureFeedback() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isShowingCaptureFlash = true
        captureFlashTask?.cancel()
        captureFlashTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self?.isShowingCaptureFlash = false
        }
    }

    private func startRecordingTimer() {
        recordingTimerTask?.cancel()
        recordingDuration = 0
        let startDate = Date()

        recordingTimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                recordingDuration = Date().timeIntervalSince(startDate)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimerTask?.cancel()
        recordingTimerTask = nil
    }

    private func makeTemporaryFile(data: Data, fileExtension: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("animagic-\(UUID().uuidString)", isDirectory: false)
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func removeTemporaryFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func makeBackCamera() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        return discoverySession.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    nonisolated private static func makeVideoThumbnail(
        url: URL,
        completion: @escaping (UIImage?) -> Void
    ) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.generateCGImageAsynchronously(for: .zero) { image, _, _ in
            completion(image.map(UIImage.init(cgImage:)))
        }
    }
}

private enum NativeCameraError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case inputUnavailable
    case photoOutputUnavailable
    case movieOutputUnavailable
    case photoDataUnavailable
    case recordingUnavailable
    case videoThumbnailUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "The back camera is not available on this device."
        case .microphoneUnavailable:
            "The microphone is not available on this device."
        case .inputUnavailable:
            "The camera inputs could not be configured."
        case .photoOutputUnavailable:
            "Photo capture is not available on this device."
        case .movieOutputUnavailable:
            "Video capture is not available on this device."
        case .photoDataUnavailable:
            "The captured photo could not be prepared for review."
        case .recordingUnavailable:
            "The recorded video could not be prepared for review."
        case .videoThumbnailUnavailable:
            "The recorded video could not be previewed."
        }
    }
}

private final class NativeCameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(NativeCameraError.photoDataUnavailable))
            return
        }
        completion(.success(data))
    }
}

private final class NativeCameraMovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let completion: (URL?, Error?) -> Void

    init(completion: @escaping (URL?, Error?) -> Void) {
        self.completion = completion
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        completion(outputFileURL, error)
    }
}
