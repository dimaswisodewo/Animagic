//
//  MotionOrientationStore.swift
//  Animagic
//
//  Created by dimaswisodewo on 15/07/26.
//

import CoreMotion
import simd

struct MotionOrientationSnapshot: Sendable {
    let quaternion: simd_quatf
    let timestamp: TimeInterval
}

final class MotionOrientationStore: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var snapshot: MotionOrientationSnapshot?

    nonisolated func write(quaternion: simd_quatf, timestamp: TimeInterval) {
        lock.lock()
        snapshot = MotionOrientationSnapshot(quaternion: quaternion, timestamp: timestamp)
        lock.unlock()
    }

    nonisolated func read() -> MotionOrientationSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshot
    }
}
