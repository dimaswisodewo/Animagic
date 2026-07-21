//
//  NativeCameraComponent.swift
//  AniMagic
//
//  Created by MorpKnight on 21/07/26.
//

import SwiftUI

struct NativeCameraComponent: View {
    @StateObject private var viewModel = NativeCameraViewModel()

    var body: some View {
        NativeCameraView(viewModel: viewModel)
    }
}

#if DEBUG
#Preview {
    NativeCameraComponent()
}
#endif
