//
//  NativeCameraComponent.swift
//  AniMagic
//
//  Created by MorpKnight on 21/07/26.
//

import SwiftUI

struct NativeCameraComponent: View {
    @Environment(HapticFeedbackManager.self) private var haptics
    @StateObject private var viewModel = NativeCameraViewModel()

    var body: some View {
        NativeCameraView(viewModel: viewModel)
            .onAppear {
                viewModel.configure(haptics: haptics)
            }
    }
}

#if DEBUG
#Preview {
    NativeCameraComponent()
        .environment(HapticFeedbackManager(defaults: UserDefaults(suiteName: "CameraPreview")!))
}
#endif
