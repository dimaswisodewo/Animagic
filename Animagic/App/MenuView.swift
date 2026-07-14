//
//  MenuView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

struct MenuView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)

                Text("Animagic")
                    .font(.largeTitle.bold())

                Text("Choose an experience")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    NavigationLink {
                        CutoutLibraryView()
                    } label: {
                        Label("AR View", systemImage: "arkit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    NavigationLink {
                        VirtualRoomView()
                    } label: {
                        Label("RealityKit View", systemImage: "cube.transparent")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 12)
            }
            .padding(24)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
