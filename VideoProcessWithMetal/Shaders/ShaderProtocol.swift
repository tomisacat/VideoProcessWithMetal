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
    var identifier: String { get }
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture)
}

//class ShaderStub: ShaderProtocol {
//    var identifier: String = ""
//
//    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {}
//
//    static func ==(lhs: ShaderStub, rhs: ShaderStub) -> Bool {
//        return false
//    }
//}

