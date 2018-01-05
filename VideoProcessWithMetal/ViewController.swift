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
    @IBOutlet weak var shaderSwitch: UISwitch!
    
    let captureSession = AVCaptureSession()
    let sampleBufferCallbackQueue = DispatchQueue(label: "video.process.metal")
    var writer: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var adaptor: AVAssetWriterInputPixelBufferAdaptor!
    var isRecording: Bool = false
    
    var lastSampleTime: CMTime = kCMTimeZero
    var processedPixelBuffer: CVPixelBuffer?
    
    private let separateRGB = SeparateRGB()
    private let diffusion = Diffusion()
    private let blurredMotion = BlurredMotion()
    
    // method
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        configCaptureSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sampleBufferCallbackQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    private func setupView() {
        mtkView.device = MetalManager.shared.device
        mtkView.framebufferOnly = false
        mtkView.delegate = self
        mtkView.colorPixelFormat = MetalManager.shared.colorPixelFormat
        mtkView.contentMode = .scaleAspectFit
        mtkView.isPaused = true
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

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        MetalManager.shared.processNext(pixelBuffer: pixelBuffer)
        lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        DispatchQueue.main.sync {
            mtkView.draw()
        }
    }
}

extension ViewController: MTKViewDelegate {
    func draw(in view: MTKView) {
        guard let currentDrawable = mtkView.currentDrawable,
            let texture = MetalManager.shared.sourceTexture,
            let commandBuffer = MetalManager.shared.commandQueue?.makeCommandBuffer() else {
            return
        }
        
        let shader: ShaderProtocol
        if shaderSwitch.isOn {
            shader = separateRGB
        } else {
            shader = blurredMotion
        }
        
        shader.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: currentDrawable.texture)
        append(texture: currentDrawable.texture)
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    private func append(texture: MTLTexture) {
        if self.isRecording && adaptor.assetWriterInput.isReadyForMoreMediaData {
            guard let pbp = adaptor.pixelBufferPool else {
                return
            }
            
            if processedPixelBuffer == nil {
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pbp, &processedPixelBuffer)
            }
            
            guard let p = processedPixelBuffer else {
                return
            }
            
            CVPixelBufferLockBaseAddress(p, CVPixelBufferLockFlags(rawValue: 0))
            
            let region = MTLRegionMake2D(0, 0, 720, 1280)
            let buffer = CVPixelBufferGetBaseAddress(p)
            let bytesPerRow = 4 * region.size.width
            texture.getBytes(buffer!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            
            adaptor.append(p, withPresentationTime: lastSampleTime)
            
            CVPixelBufferUnlockBaseAddress(p, CVPixelBufferLockFlags(rawValue: 0))
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
