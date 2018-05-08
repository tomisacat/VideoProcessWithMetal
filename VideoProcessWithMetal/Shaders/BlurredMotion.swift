//
//  BlurredMotion.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 05/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

import Foundation
import Metal
import MetalKit

class BlurredMotion: ShaderProtocol {
    private var computePipelineState: MTLComputePipelineState?
    private var lastTexture: MTLTexture?
    var identifier: String
    
    init() {
        computePipelineState = MetalManager.shared.makeComputePipelineState(functionName: "blurredMotion")
        identifier = String.random()
    }
    
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        guard let cps = computePipelineState else {
            return
        }
        
        if lastTexture == nil {
            lastTexture = sourceTexture.makeTextureView(pixelFormat: sourceTexture.pixelFormat)
        }
        
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(cps)
        computeCommandEncoder?.setTexture(sourceTexture, index: 0)
        computeCommandEncoder?.setTexture(destinationTexture, index: 1)
        computeCommandEncoder?.setTexture(lastTexture, index: 2)
        
        var diff = MetalManager.shared.nextTime
        computeCommandEncoder?.setBytes(&diff, length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder?.dispatchThreadgroups(sourceTexture.threadGroups(pipeline: cps),
                                                    threadsPerThreadgroup: sourceTexture.threadGroupCount(pipeline: cps))
        computeCommandEncoder?.endEncoding()
        
        lastTexture = destinationTexture
    }
}
