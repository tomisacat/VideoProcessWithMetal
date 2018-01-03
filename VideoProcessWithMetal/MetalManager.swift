//
//  MetalManager.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 03/01/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders

class MetalManager: NSObject {
    static let shared: MetalManager = MetalManager()
    
    let device = MTLCreateSystemDefaultDevice()!
    var sourceTexture: MTLTexture?
    var destinationTexture: MTLTexture?
    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    
    private(set) var beginTime = CACurrentMediaTime()
    var time: Float = 0
    
    private var library: MTLLibrary?
    private(set) var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    
    private override init() {
        super.init()
        
        library = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    // MARK: - Public
    
    func makeComputePipelineState(functionName: String) -> MTLComputePipelineState? {
        guard let function = library?.makeFunction(name: functionName) else {
            return nil
        }
        
        return try? device.makeComputePipelineState(function: function)
    }
    
    func processNext(pixelBuffer: CVPixelBuffer) {
        guard let tc = textureCache else {
            return
        }
        
        var cvmTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  tc,
                                                  pixelBuffer,
                                                  nil,
                                                  colorPixelFormat,
                                                  width,
                                                  height,
                                                  0,
                                                  &cvmTexture)
        if let cvmTexture = cvmTexture, let texture = CVMetalTextureGetTexture(cvmTexture) {
            sourceTexture = texture
        }
    }
}
