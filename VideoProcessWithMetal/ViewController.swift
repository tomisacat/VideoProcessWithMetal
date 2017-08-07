//
//  ViewController.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 03/08/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import UIKit
import AVFoundation
import MetalKit
import CoreVideo

class ViewController: UIViewController {
    
    // IBOutlet
    @IBOutlet var mtkView: MTKView!
    
    // property
    let device = MTLCreateSystemDefaultDevice()!
    lazy var commandQueue: MTLCommandQueue = {
        return self.device.makeCommandQueue()!
    }()
    var computePipelineState: MTLComputePipelineState?
    var sourceTexture: MTLTexture?
    var textureCache: CVMetalTextureCache?
    
    let captureSession = AVCaptureSession()
    let sampleBufferCallbackQueue = DispatchQueue(label: "video.process.metal")
    
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    var isRecording: Bool = false
    
    var beginTime = CACurrentMediaTime()
    var lastSampleTime: CMTime = kCMTimeZero
    var processedPixelBuffer: CVPixelBuffer?
    
    // method
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        initializeComputePipeline()
        createTextureCache()
        configCaptureSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sampleBufferCallbackQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    private func setupView() {
        mtkView.device = device
        mtkView.framebufferOnly = false
        mtkView.delegate = self
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.contentMode = .scaleAspectFit
        mtkView.isPaused = true
    }
    
    private func createTextureCache() {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    private func configCaptureSession() {
        captureSession.beginConfiguration()
        
        // preset
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        
        // video input
        guard let camera = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            return
        }
        
        // video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferCallbackQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
            }
        }
        
        // writer
        do {
            writer = try! AVAssetWriter(outputURL: URL.randomUrl(), fileType: .mov)
            
            let videoCompressionProperties = [
                AVVideoAverageBitRateKey: 6000000
            ]
            
            let videoSettings: [String : Any] = [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: 720,
                AVVideoHeightKey: 1280,
                AVVideoCompressionPropertiesKey: videoCompressionProperties
            ]
            
            writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = true
            writerInput.transform = .identity
            let sourcePixelBufferAttributes = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 720,
                kCVPixelBufferHeightKey as String: 1280
            ]
            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
            
            if writer.canAdd(writerInput) {
                writer.add(writerInput)
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    private func initializeComputePipeline() {
        let library = device.makeDefaultLibrary()
        let shader = library?.makeFunction(name: "separateRGB")
        computePipelineState = try! device.makeComputePipelineState(function: shader!)
    }
    
    @IBAction func captureAction(_ sender: Any) {
        let button = sender as! UIButton
        
        if button.title(for: .normal) == "Start" {
            sampleBufferCallbackQueue.sync {
                if self.writer.startWriting() {
                    self.writer.startSession(atSourceTime: lastSampleTime)
                }
                
                self.isRecording = true
            }
            
            button.setTitle("Stop", for: .normal)
        } else {
            sampleBufferCallbackQueue.sync {
                self.isRecording = false
                self.writer.finishWriting {
                    self.writer.outputURL.saveToAlbum()
                }
            }
            
            button.setTitle("Start", for: .normal)
        }
    }
}

extension ViewController: MTKViewDelegate {
    func draw(in view: MTKView) {
        guard let currentDrawable = mtkView.currentDrawable, let texture = sourceTexture else {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(computePipelineState!)
        computeCommandEncoder?.setTexture(texture, index: 0)
        computeCommandEncoder?.setTexture(currentDrawable.texture, index: 1)
        
        var diff = Float(CACurrentMediaTime() - beginTime)
        computeCommandEncoder?.setBytes(&diff, length: MemoryLayout<Float>.size, index: 0)
        computeCommandEncoder?.dispatchThreadgroups(texture.threadGroups(pipeline: computePipelineState!), threadsPerThreadgroup: texture.threadGroupCount(pipeline: computePipelineState!))
        computeCommandEncoder?.endEncoding()
        
        if self.isRecording && adaptor.assetWriterInput.isReadyForMoreMediaData {
            if processedPixelBuffer == nil {
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &processedPixelBuffer)
            }
            
            guard let p = processedPixelBuffer else {
                return
            }
            
            CVPixelBufferLockBaseAddress(p, CVPixelBufferLockFlags(rawValue: 0))
            
            let outputTexture = currentDrawable.texture
            let region = MTLRegionMake2D(0, 0, 720, 1280)
            
            let buffer = CVPixelBufferGetBaseAddress(p)
            let bytesPerRow = 4 * region.size.width
            outputTexture.getBytes(buffer!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            
            adaptor.append(p, withPresentationTime: lastSampleTime)
            
            CVPixelBufferUnlockBaseAddress(p, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        commandBuffer?.present(currentDrawable)
        commandBuffer?.commit()
//        commandBuffer?.waitUntilCompleted()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var cvmTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, mtkView.colorPixelFormat, width, height, 0, &cvmTexture)
        if let cvmTexture = cvmTexture, let texture = CVMetalTextureGetTexture(cvmTexture) {
            sourceTexture = texture
        }
        
        lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        DispatchQueue.main.sync {
            mtkView.draw()
        }
    }
}

extension MTLTexture {
    func threadGroupCount(pipeline: MTLComputePipelineState) -> MTLSize {
        return MTLSizeMake(pipeline.threadExecutionWidth,
                           pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth,
                           1)
    }
    
    func threadGroups(pipeline: MTLComputePipelineState) -> MTLSize {
        let groupCount = threadGroupCount(pipeline: pipeline)
        return MTLSizeMake((self.width + groupCount.width - 1) / groupCount.width, (self.height + groupCount.height - 1) / groupCount.height, 1)
    }
}
