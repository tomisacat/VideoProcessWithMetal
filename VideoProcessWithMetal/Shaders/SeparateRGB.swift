//
//  SeparateRGB.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 26/12/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import Foundation
import Metal
import UIKit

class SeparateRGB: ShaderProtocol {
    private var computePipelineState: MTLComputePipelineState?
    
    init() {
        computePipelineState = MetalManager.shared.makeComputePipelineState(functionName: "separateRGB")
    }
    
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        guard let cps = computePipelineState else {
            return
        }
        
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(cps)
        computeCommandEncoder?.setTexture(sourceTexture, index: 0)
        computeCommandEncoder?.setTexture(destinationTexture, index: 1)
        
        var diff = Float(CACurrentMediaTime() - MetalManager.shared.beginTime)
        computeCommandEncoder?.setBytes(&diff, length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder?.dispatchThreadgroups(sourceTexture.threadGroups(pipeline: cps),
                                                    threadsPerThreadgroup: sourceTexture.threadGroupCount(pipeline: cps))
        computeCommandEncoder?.endEncoding()
    }
}