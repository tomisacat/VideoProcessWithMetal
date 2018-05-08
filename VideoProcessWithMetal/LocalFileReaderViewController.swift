//
//  LocalFileViewController.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 07/05/2018.
//  Copyright © 2018 tomisacat. All rights reserved.
//

import UIKit
import MetalKit
import AVFoundation

class LocalFileReaderViewController: UIViewController {
    
    @IBOutlet weak var hintLabel: UILabel!
    
    let shader = SeparateRGB()
    var processedPixelBuffer: CVPixelBuffer?
    var lastSampleTime: CMTime = kCMTimeZero
    
    var reader: AVAssetReader!
    var readerOutput: AVAssetReaderTrackOutput!
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    let inputQueue = DispatchQueue(label: "video.process.metal.local.file.reader")
    var started = false
    var intermediateTexture: MTLTexture!
    
    let semaphore = DispatchSemaphore(value: 1)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mov") else {
            print("no video")
            return
        }
        
        let asset = AVURLAsset(url: url)
        
        do {
            // reader
            reader = try AVAssetReader(asset: asset)
            readerOutput = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video).first!,
                                                    outputSettings: [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String: Any])
            if reader.canAdd(readerOutput) {
                reader.add(readerOutput)
            }
            reader.startReading()
            
            // writer
            writer = try AVAssetWriter(outputURL: URL.randomUrl(), fileType: .mov)
            let videoCompressionProperties = [
                AVVideoAverageBitRateKey: 12000000
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
            
            self.writer.startWriting()
        } catch {
            print("error")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        export()
    }
    
    func export() {
        writerInput.requestMediaDataWhenReady(on: inputQueue) {
            while self.writerInput.isReadyForMoreMediaData {
                _ = self.semaphore.wait(timeout: .distantFuture)
                
                if let sb = self.readerOutput.copyNextSampleBuffer() {
                    self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sb)
                    
                    if !self.started {
                        self.writer.startSession(atSourceTime: self.lastSampleTime)
                        self.started = true
                    }
                    
                    MetalManager.shared.processNext(sb)
                    
                    if let texture = MetalManager.shared.sourceTexture {
                        if let commandBuffer = MetalManager.shared.commandQueue?.makeCommandBuffer() {
                            if self.intermediateTexture == nil {
                                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
                                descriptor.usage = [.shaderRead, .shaderWrite]
                                descriptor.storageMode = .shared
                                self.intermediateTexture = commandBuffer.device.makeTexture(descriptor: descriptor)
                            }
                            
                            self.shader.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: self.intermediateTexture)
                            commandBuffer.addCompletedHandler({ (_) in
                                self.semaphore.signal()
                            })
                            self.append(texture: self.intermediateTexture)
                            commandBuffer.commit()
//                            commandBuffer.waitUntilCompleted()
                            
                        } else {
                            print("no command buffer")
                        }
                    } else {
                        print("no source texture")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.hintLabel.text = "Done!"
                    }
                    
                    self.writerInput.markAsFinished()
                    self.writer.finishWriting {
                        self.writer.outputURL.saveToAlbum()
                    }
                    
                    break
                }
            }
        }
    }
    
    func append(texture: MTLTexture) {
        if self.adaptor.assetWriterInput.isReadyForMoreMediaData {
            guard let pbp = self.adaptor.pixelBufferPool else {
                return
            }
            
            if self.processedPixelBuffer == nil {
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pbp, &self.processedPixelBuffer)
            }
            
            guard let p = self.processedPixelBuffer else {
                return
            }
            
            CVPixelBufferLockBaseAddress(p, CVPixelBufferLockFlags(rawValue: 0))
            
            let region = MTLRegionMake2D(0, 0, 720, 1280)
            let buffer = CVPixelBufferGetBaseAddress(p)
            let bytesPerRow = 4 * region.size.width
            texture.getBytes(buffer!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            
            self.adaptor.append(p, withPresentationTime: self.lastSampleTime)
            
            CVPixelBufferUnlockBaseAddress(p, CVPixelBufferLockFlags(rawValue: 0))
        }
    }
}
