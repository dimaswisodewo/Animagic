//
//  MotionLabView.swift
//  AniMagic
//
//  Created by Meynabel Dimas Wisodewo on 21/07/26.
//

#if DEBUG
import Observation
import SwiftUI

@MainActor
@Observable
private final class MotionLabModel {
    var locomotion: AnimalLocomotion = .walk { didSet { reset() } }
    private(set) var sample: MotionSample
    private var configuration: MotionInstanceConfiguration
    private var simulator: MotionSimulator

    init() {
        let initialConfiguration = MotionInstanceConfiguration.make(
            for: .walk,
            spawnMode: .plane,
            physicalWidth: 0.35,
            seed: 42
        )
        var initialSimulator = MotionSimulator(yaw: 0, configuration: initialConfiguration)
        let initialSample = initialSimulator.update(
            deltaTime: 0,
            locomotion: .walk,
            configuration: initialConfiguration,
            initialYaw: 0
        )

        configuration = initialConfiguration
        simulator = initialSimulator
        sample = initialSample
    }

    func step() {
        sample = simulator.update(deltaTime: 1 / 60, locomotion: locomotion, configuration: configuration, initialYaw: 0)
    }

    func react() { simulator.receive(.tapped) }

    func reset() {
        configuration = MotionInstanceConfiguration.make(for: locomotion, spawnMode: .plane, physicalWidth: 0.35, seed: 42)
        simulator = MotionSimulator(yaw: 0, configuration: configuration)
        sample = simulator.update(deltaTime: 0, locomotion: locomotion, configuration: configuration, initialYaw: 0)
    }
}

struct MotionLabView: View {
    @State private var model = MotionLabModel()

    var body: some View {
        VStack(spacing: 18) {
            Canvas { context, size in
                let center = CGPoint(
                    x: size.width / 2 + CGFloat(model.sample.position.x) * 180,
                    y: size.height * 0.68 - CGFloat(model.sample.position.y) * 180
                )
                context.fill(Path(CGRect(x: 0, y: size.height * 0.7, width: size.width, height: 2)), with: .color(.secondary))
                var body = context.resolve(Image(systemName: model.locomotion.systemImageName))
                body.shading = .color(.accentColor)
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: .radians(Double(model.sample.roll)))
                context.scaleBy(x: CGFloat(model.sample.scaleX) * 4, y: CGFloat(model.sample.scaleY) * 4)
                context.draw(body, at: .zero, anchor: .center)
            }
            .frame(height: 320)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))

            Picker("Locomotion", selection: $model.locomotion) {
                ForEach(AnimalLocomotion.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Tap reaction", action: model.react).buttonStyle(.borderedProminent)
                Button("Reset seed", action: model.reset).buttonStyle(.bordered)
            }

            Grid(alignment: .leading) {
                GridRow { Text("Phase"); Text(model.sample.deformationPhase, format: .number.precision(.fractionLength(3))) }
                GridRow { Text("Contact"); Text(model.sample.contact, format: .number.precision(.fractionLength(3))) }
                GridRow { Text("Attention"); Text(model.sample.attention, format: .number.precision(.fractionLength(3))) }
            }
            .monospacedDigit()
        }
        .padding()
        .navigationTitle("Motion Lab")
        .task {
            while !Task.isCancelled {
                model.step()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}
#endif
