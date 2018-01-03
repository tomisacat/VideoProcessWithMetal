//
//  Utils.swift
//  VideoProcessWithMetal
//
//  Created by tomisacat on 04/08/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import Foundation
import UIKit

extension URL {
    static public func randomUrl() -> URL {
        let path = NSTemporaryDirectory() + "/" + String.random(length: 5) + ".mov"
        return URL(fileURLWithPath: path)
    }
    
    public func saveToAlbum() {
        UISaveVideoAtPathToSavedPhotosAlbum(self.path, nil, nil, nil)
    }
}

extension String {
    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""
        
        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
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
