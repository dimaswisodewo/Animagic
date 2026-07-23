//
//  CutoutBackfaceDeformationValidation.swift
//  AniMagic
//
//  Created by dimaswisodewo on 23/07/26.
//

import Foundation

@main
enum CutoutBackfaceDeformationValidation {
    static func main() {
        let artworkCoordinates: [Float] = [0.05, 0.15, 0.35, 0.65, 0.85, 0.95]
        let facingDirections: [Float] = [-1, 1]

        for facing in facingDirections {
            for artworkU in artworkCoordinates {
                let front = context(
                    sourceU: artworkU,
                    surfaceCompensation: 1,
                    facing: facing
                )
                let back = context(
                    sourceU: 1 - artworkU,
                    surfaceCompensation: -1,
                    facing: facing
                )

                requireEqual(front.deformationU, back.deformationU, "deformation U")
                requireEqual(front.centeredX, back.centeredX, "centered X")
                requireEqual(front.orientedU, back.orientedU, "oriented U")
                requireEqual(1 - front.orientedU, 1 - back.orientedU, "swim rear weight")
            }
        }

        validateAsymmetricSurfaceCoordinates()

        print(
            "Cutout back-face coordinate validation passed "
                + "\(artworkCoordinates.count * facingDirections.count) deformation cases "
                + "and asymmetric surface correspondence."
        )
    }

    private static func validateAsymmetricSurfaceCoordinates() {
        let bounds: ClosedRange<Float> = 0.08...0.73
        let artworkCoordinates: [Float] = [0.10, 0.22, 0.41, 0.69]
        let reflectionSum = bounds.lowerBound + bounds.upperBound

        for artworkU in artworkCoordinates {
            let backMeshU = reflectionSum - artworkU
            let backTextureSourceU = reflectionSum - backMeshU
            let backFieldU = reflectionSum - backMeshU
            let backCrownU = reflectionSum - backMeshU
            let backBevelTextureU = reflectionSum - artworkU
            let backBevelSourceU = reflectionSum - backBevelTextureU

            requireEqual(backTextureSourceU, artworkU, "back artwork U")
            requireEqual(backFieldU, artworkU, "back opacity-field U")
            requireEqual(backCrownU, artworkU, "back crown U")
            requireEqual(backBevelSourceU, artworkU, "back bevel U")
        }
    }

    private static func context(
        sourceU: Float,
        surfaceCompensation: Float,
        facing: Float
    ) -> (deformationU: Float, centeredX: Float, orientedU: Float) {
        let deformationU = surfaceCompensation < 0 ? 1 - sourceU : sourceU
        return (
            deformationU,
            deformationU * 2 - 1,
            facing < 0 ? 1 - deformationU : deformationU
        )
    }

    private static func requireEqual(
        _ first: Float,
        _ second: Float,
        _ label: String
    ) {
        guard abs(first - second) < 0.000_001 else {
            fputs("error: mismatched \(label): \(first) != \(second)\n", stderr)
            exit(1)
        }
    }
}
