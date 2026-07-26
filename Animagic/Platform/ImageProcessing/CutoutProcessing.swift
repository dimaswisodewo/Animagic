//
//  CutoutProcessing.swift
//  Animagic
//
//  Created by Meynabel Dimas Wisodewo on 14/07/26.
//

import Foundation

protocol CutoutProcessing {
    func makeCutout(from imageData: Data) async throws -> CutoutAsset
}
