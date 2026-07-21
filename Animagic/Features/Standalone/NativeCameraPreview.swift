//
//  NativeCameraPreview.swift
//  AniMagic
//
//  Created by MorpKnight on 20/07/26.
//

import AVFoundation
import SwiftUI

struct NativeCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let viewModel: NativeCameraViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> NativeCameraPreviewView {
        let view = NativeCameraPreviewView()
        viewModel.configurePreviewLayer(view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: NativeCameraPreviewView, context: Context) {
        viewModel.configurePreviewLayer(uiView.previewLayer)
    }

    static func dismantleUIView(_ uiView: NativeCameraPreviewView, coordinator: Coordinator) {
        coordinator.viewModel.removePreviewLayer(uiView.previewLayer)
        uiView.previewLayer.session = nil
    }

    final class Coordinator {
        let viewModel: NativeCameraViewModel

        init(viewModel: NativeCameraViewModel) {
            self.viewModel = viewModel
        }
    }
}

final class NativeCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("NativeCameraPreviewView must use AVCaptureVideoPreviewLayer")
        }
        return previewLayer
    }
}
