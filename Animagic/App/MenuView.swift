//
//  MenuView.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import SwiftUI

struct MenuView: View {
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)

                Text("Animagic")
                    .font(.largeTitle.bold())

                Text("Choose an experience")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button {
                        router.push(.cutoutLibrary)
                    } label: {
                        Label("AR View", systemImage: "arkit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        router.push(.virtualRoom)
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
