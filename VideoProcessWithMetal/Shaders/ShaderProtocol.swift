//
//  ShaderProtocol.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 25/12/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import Foundation
import CoreMedia
import MetalKit
import MetalPerformanceShaders

protocol ShaderProtocol {
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture)
}
