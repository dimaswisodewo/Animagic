//
//  SurfaceProjectors.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import ARKit
import RealityKit
import UIKit

@MainActor
protocol SurfaceProjecting {
    func project(
        _ point: CGPoint,
        in arView: ARView
    ) -> SurfaceProjection?

    func project(
        _ point: CGPoint,
        in arView: ARView,
        for object: any PlacedSceneObject
    ) -> SurfaceProjection?
}

struct ARSurfaceProjector: SurfaceProjecting {
    func project(_ point: CGPoint, in arView: ARView) -> SurfaceProjection? {
        let existing = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        ).first
        let result = existing ?? arView.raycast(
            from: point,
            allowing: .estimatedPlane,
            alignment: .horizontal
        ).first

        guard let result else {
            return nil
        }
        return SurfaceProjection(
            position: result.worldTransform.translation,
            normal: simd_normalize([
                result.worldTransform.columns.1.x,
                result.worldTransform.columns.1.y,
                result.worldTransform.columns.1.z
            ])
        )
    }

    func project(
        _ point: CGPoint,
        in arView: ARView,
        for object: any PlacedSceneObject
    ) -> SurfaceProjection? {
        project(point, in: arView)
    }
}

struct NonARPlaneProjector: SurfaceProjecting {
    let planeTransform: simd_float4x4
    var horizontalBounds: ClosedRange<Float>? = nil

    func project(_ point: CGPoint, in arView: ARView) -> SurfaceProjection? {
        guard let position = arView.unproject(point, ontoPlane: planeTransform) else {
            return nil
        }
        if let horizontalBounds,
           (!horizontalBounds.contains(position.x) || !horizontalBounds.contains(position.z)) {
            return nil
        }
        return SurfaceProjection(
            position: position,
            normal: simd_normalize([
                planeTransform.columns.2.x,
                planeTransform.columns.2.y,
                planeTransform.columns.2.z
            ])
        )
    }

    func project(
        _ point: CGPoint,
        in arView: ARView,
        for object: any PlacedSceneObject
    ) -> SurfaceProjection? {
        project(point, in: arView)
    }
}
