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

class LocalFileViewController: UIViewController {

    @IBOutlet var mtkView: MTKView!
    
    let player = AVPlayer()
    lazy var playerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var displayLink: CADisplayLink = {
        let dl = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        dl.add(to: .current, forMode: .defaultRunLoopMode)
        dl.isPaused = true
        return dl
    }()
    
    let shader = SeparateRGB()
    
    var processedPixelBuffer: CVPixelBuffer?
    var lastSampleTime: CMTime = kCMTimeZero
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    let inputQueue = DispatchQueue(label: "video.process.metal.local.file")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mov") else {
            print("no video")
            return
        }
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.add(playerItemVideoOutput)
        player.replaceCurrentItem(with: playerItem)
        
        do {
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
            
            inputQueue.sync {
                writer.startWriting()
                writer.startSession(atSourceTime: lastSampleTime)
            }
        } catch {
            print("error")
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (_) in
            print("end")
            
            self.inputQueue.sync {
                self.writer.finishWriting {
                    self.writer.outputURL.saveToAlbum()
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        player.play()
        displayLink.isPaused = false
    }
    
    private func setupView() {
        mtkView.device = MetalManager.shared.device
        mtkView.framebufferOnly = false
        mtkView.delegate = self
        mtkView.colorPixelFormat = MetalManager.shared.colorPixelFormat
        mtkView.contentMode = .scaleAspectFit
        mtkView.isPaused = true
    }
    
    @objc func readBuffer(_ sender: CADisplayLink) {
        var currentTime = kCMTimeInvalid
        let nextVSync = sender.timestamp + sender.duration
        currentTime = playerItemVideoOutput.itemTime(forHostTime: nextVSync)
        
        if playerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime), let pixelBuffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
            lastSampleTime = currentTime
            MetalManager.shared.processNext(pixelBuffer)
            DispatchQueue.main.async {
                self.mtkView.draw()
            }
        }
    }
}

extension LocalFileViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let currentDrawable = mtkView.currentDrawable,
            let texture = MetalManager.shared.sourceTexture,
            let commandBuffer = MetalManager.shared.commandQueue?.makeCommandBuffer() else {
                return
        }

        shader.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: currentDrawable.texture)

        append(texture: currentDrawable.texture)
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    func append(texture: MTLTexture) {
        inputQueue.sync {
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
}
