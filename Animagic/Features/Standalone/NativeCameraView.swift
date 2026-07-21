//
//  NativeCameraView.swift
//  AniMagic
//
//  Created by MorpKnight on 20/07/26.
//

import AVKit
import SwiftUI

struct NativeCameraView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var viewModel: NativeCameraViewModel
    @State private var isShutterPressing = false
    @State private var didStartRecording = false
    @State private var didCrossLongPressThreshold = false
    @State private var shutterPressTask: Task<Void, Never>?

    init(viewModel: NativeCameraViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack {
            switch viewModel.authorizationState {
            case .checking:
                permissionLoadingView
            case .authorized:
                cameraContent
            case .denied(let message):
                permissionDeniedView(message: message)
            }

            if viewModel.isShowingCaptureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if let media = viewModel.capturedMedia {
                NativeCameraReviewView(
                    media: media,
                    isSaving: viewModel.isSaving,
                    onCancel: viewModel.cancelReview,
                    onConfirm: viewModel.confirmReview
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
                .zIndex(2)
            }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.28), value: viewModel.capturedMedia?.id)
        .animation(.easeOut(duration: 0.12), value: viewModel.isShowingCaptureFlash)
        .onAppear {
            viewModel.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.resumeSession()
            case .inactive, .background:
                cancelShutterPress()
                viewModel.pauseSession()
            @unknown default:
                break
            }
        }
        .onDisappear {
            cancelShutterPress()
            viewModel.stop()
        }
        .alert(
            viewModel.errorMessage == nil ? "Saved" : "Camera",
            isPresented: messageAlertIsPresented
        ) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.errorMessage ?? viewModel.feedbackMessage ?? "")
        }
    }

    private var cameraContent: some View {
        ZStack {
            NativeCameraPreview(session: viewModel.session, viewModel: viewModel)
                .ignoresSafeArea()

            cameraGradient
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                cameraHeader

                Spacer()

                cameraControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }

    private var cameraGradient: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.56), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            Spacer()

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
        }
    }

    private var cameraHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Magic Camera")
                .font(.custom("Belanosima-SemiBold", size: 27, relativeTo: .title3))
                .foregroundStyle(.white)

            Spacer()

            if viewModel.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)

                    Text(viewModel.formattedRecordingDuration)
                        .font(.custom("Belanosima-SemiBold", size: 17, relativeTo: .headline))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.red.opacity(0.86), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Recording \(viewModel.formattedRecordingDuration)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.28), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var cameraControls: some View {
        HStack(alignment: .bottom) {
            latestThumbnail
                .frame(maxWidth: .infinity, alignment: .leading)

            shutterButton

            Color.clear
                .frame(width: 72, height: 72)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var latestThumbnail: some View {
        Group {
            if let latestThumbnail = viewModel.latestThumbnail {
                Image(uiImage: latestThumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .accessibilityLabel("Latest capture")
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.7), lineWidth: 2)
                    }
                    .accessibilityLabel("No captures yet")
            }
        }
    }

    private var shutterButton: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 88, height: 88)

            Circle()
                .fill(viewModel.isRecording ? .red : AnimagicTheme.orange)
                .frame(width: 70, height: 70)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                }

            if viewModel.isRecording {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.white)
                    .frame(width: 24, height: 24)
            }
        }
        .scaleEffect(isShutterPressing ? 0.92 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isShutterPressing)
        .frame(width: 88, height: 88)
        .disabled(viewModel.capturedMedia != nil || viewModel.isSaving)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let distance = hypot(value.translation.width, value.translation.height)
                    guard distance <= 28 else {
                        cancelShutterPress()
                        return
                    }
                    beginShutterPress()
                }
                .onEnded { _ in
                    finishShutterPress()
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(viewModel.isRecording ? "Stop recording" : "Capture photo")
        .accessibilityHint("Tap to take a photo. Press and hold to record video.")
        .accessibilityAction {
            viewModel.capturePhoto()
        }
    }

    private var permissionLoadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(AnimagicTheme.orange)

            Text("Preparing camera…")
                .font(.custom("Belanosima-SemiBold", size: 26, relativeTo: .title3))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func permissionDeniedView(message: String) -> some View {
        VStack(spacing: 22) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(AnimagicTheme.orange)
                .padding(20)
                .background(.white.opacity(0.12), in: Circle())

            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.custom("Belanosima-SemiBold", size: 30, relativeTo: .title2))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.custom("Belanosima-Regular", size: 18, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }

            Button("Open Settings", action: viewModel.openSettings)
                .font(.custom("Belanosima-SemiBold", size: 20, relativeTo: .headline))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .background(AnimagicTheme.orange, in: Capsule())
                .overlay(Capsule().stroke(.black, lineWidth: 3))
                .buttonStyle(.animagicPress)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private var messageAlertIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || viewModel.feedbackMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearMessages()
                }
            }
        )
    }

    private func beginShutterPress() {
        guard !isShutterPressing else { return }

        isShutterPressing = true
        didStartRecording = false
        didCrossLongPressThreshold = false
        shutterPressTask?.cancel()
        shutterPressTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, isShutterPressing else { return }

            didCrossLongPressThreshold = true
            didStartRecording = viewModel.beginRecording()
        }
    }

    private func finishShutterPress() {
        shutterPressTask?.cancel()
        shutterPressTask = nil

        guard isShutterPressing else { return }
        isShutterPressing = false

        if didStartRecording || viewModel.isRecording {
            viewModel.stopRecording()
        } else if !didCrossLongPressThreshold {
            viewModel.capturePhoto()
        }

        didStartRecording = false
        didCrossLongPressThreshold = false
    }

    private func cancelShutterPress() {
        shutterPressTask?.cancel()
        shutterPressTask = nil

        if viewModel.isRecording {
            viewModel.stopRecording()
        }
        isShutterPressing = false
        didStartRecording = false
        didCrossLongPressThreshold = false
    }
}

private struct NativeCameraReviewView: View {
    let media: NativeCameraCapturedMedia
    let isSaving: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            mediaPreview

            VStack(spacing: 0) {
                HStack {
                    Text(media.kind == .photo ? "Review Photo" : "Review Video")
                        .font(.custom("Belanosima-SemiBold", size: 26, relativeTo: .title3))
                        .foregroundStyle(.white)

                    Spacer()

                    if media.kind == .video {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.black.opacity(0.46))

                Spacer()

                HStack(spacing: 14) {
                    Button("Retake", action: onCancel)
                        .reviewButtonStyle(background: .white.opacity(0.88), foreground: .black)
                        .disabled(isSaving)

                    Button("Save to Photos", action: onConfirm)
                        .reviewButtonStyle(background: AnimagicTheme.orange, foreground: .black)
                        .disabled(isSaving)
                }
                .overlay {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(AnimagicTheme.orange, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            if media.kind == .video {
                player = AVPlayer(url: media.fileURL)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    @ViewBuilder
    private var mediaPreview: some View {
        switch media.kind {
        case .photo:
            Image(uiImage: media.previewImage)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 12)
        case .video:
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

private struct NativeCameraReviewButtonStyle: ViewModifier {
    let background: Color
    let foreground: Color

    func body(content: Content) -> some View {
        content
            .font(.custom("Belanosima-SemiBold", size: 19, relativeTo: .headline))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(.black, lineWidth: 2))
            .buttonStyle(.animagicPress)
    }
}

private extension View {
    func reviewButtonStyle(background: Color, foreground: Color) -> some View {
        modifier(NativeCameraReviewButtonStyle(background: background, foreground: foreground))
    }
}

#if DEBUG
#Preview {
    NativeCameraComponent()
}
#endif
