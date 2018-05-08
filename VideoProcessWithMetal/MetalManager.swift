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
import CoreMedia

class MetalManager: NSObject {
    static let shared: MetalManager = MetalManager()
    
    let device = MTLCreateSystemDefaultDevice()!
    var sourceTexture: MTLTexture?
    var destinationTexture: MTLTexture?
    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm

    // random time(actually NOT random)
    private let times: [Float] = (0..<50).map { 1.111 + Float($0) * 0.05 }
    private var current = 0
    var nextTime: Float {
        let t = times[current]
        current = (current + 1) % times.count
        
        return t
    }
    
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
    
    func makeRenderPipelineState(vertexName: String? = nil,
                                 fragmentName: String? = nil,
                                 colorPixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLRenderPipelineState? {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        if let vn = vertexName {
            pipelineDescriptor.vertexFunction = library?.makeFunction(name: vn)
        }
        if let fn = fragmentName {
            pipelineDescriptor.fragmentFunction = library?.makeFunction(name: fn)
        }
        
        return try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func processNext(_ pixelBuffer: CVPixelBuffer) {
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
    
    func processNext(_ sampleBuffer: CMSampleBuffer) {
        guard let cv = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        processNext(cv)
    }
}
