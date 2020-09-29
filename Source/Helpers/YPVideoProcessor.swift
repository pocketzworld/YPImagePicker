//
//  YPVideoProcessor.swift
//  YPImagePicker
//
//  Created by Nik Kov on 13.09.2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit
import AVFoundation

/*
 This class contains all support and helper methods to process the videos
 */
class YPVideoProcessor {

    /// Creates an output path and removes the file in temp folder if existing
    ///
    /// - Parameters:
    ///   - temporaryFolder: Save to the temporary folder or somewhere else like documents folder
    ///   - suffix: the file name wothout extension
    static func makeVideoPathURL(temporaryFolder: Bool, fileName: String) -> URL {
        var outputURL: URL
        
        if temporaryFolder {
            let outputPath = "\(NSTemporaryDirectory())\(fileName).\(YPConfig.video.fileType.fileExtension)"
            outputURL = URL(fileURLWithPath: outputPath)
        } else {
            guard let documentsURL = FileManager
                .default
                .urls(for: .documentDirectory,
                      in: .userDomainMask).first else {
                        print("YPVideoProcessor -> Can't get the documents directory URL")
                return URL(fileURLWithPath: "Error")
            }
            outputURL = documentsURL.appendingPathComponent("\(fileName).\(YPConfig.video.fileType.fileExtension)")
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            do {
                try fileManager.removeItem(atPath: outputURL.path)
            } catch {
                print("YPVideoProcessor -> Can't remove the file for some reason.")
            }
        }
        
        return outputURL
    }
    
    /*
     Crops the video to square by video height from the top of the video.
     */
    static func cropToSquare(filePath: URL, completion: @escaping (_ outputURL: URL?) -> Void) {
        
        // output file
        let outputPath = makeVideoPathURL(temporaryFolder: true, fileName: "squaredVideoFromCamera")
        
        // input file
        let asset = AVAsset.init(url: filePath)
        let composition = AVMutableComposition.init()
        composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        // Prevent crash if tracks is empty
        if asset.tracks.isEmpty {
            return
        }
        
        // input clip
        let clipVideoTrack = asset.tracks(withMediaType: .video)[0]
        
        // make it square
        let videoComposition = AVMutableVideoComposition()
        if YPConfig.onlySquareImagesFromCamera {
            videoComposition.renderSize = CGSize(width: CGFloat(clipVideoTrack.naturalSize.height),
												 height: CGFloat(clipVideoTrack.naturalSize.height))
        } else {
            videoComposition.renderSize = clipVideoTrack.naturalSize
        }
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
        
        // rotate to potrait
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        let finalTransform = croppedTransform(from: clipVideoTrack.preferredTransform, and: clipVideoTrack.naturalSize)
        transformer.setTransform(finalTransform, at: CMTime.zero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        // exporter
        _ = asset.export(to: outputPath, videoComposition: videoComposition, removeOldFile: true) { exportSession in
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(outputPath)
                case .failed:
                    print("YPVideoProcessor Export of the video failed: \(String(describing: exportSession.error))")
                    completion(nil)
                default:
                    print("YPVideoProcessor Export session completed with \(exportSession.status) status. Not handled.")
                    completion(nil)
                }
            }
        }
    }

    static func croppedTransform(from transform: CGAffineTransform, and size: CGSize) -> CGAffineTransform {
        let cropMargin = YPConfig.onlySquareImagesFromCamera ? (size.width - size.height) * 0.5 : 0.0
        let rotation = atan2(transform.b, transform.a)
        let translation: CGPoint

        switch orientation(from: transform) {
        case .up:
            translation = .init(x: -cropMargin, y: 0)
        case .right:
            translation = .init(x: size.height, y: -cropMargin)
        case .down:
            translation = .init(x: size.width - cropMargin, y: size.height)
        default:
            translation = .init(x: 0, y: size.width - cropMargin)
        }

        return CGAffineTransform(translationX: translation.x, y: translation.y)
            .rotated(by: rotation)
    }

    private static func orientation(from transform: CGAffineTransform) -> UIImage.Orientation {
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            return .right
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            return .left
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            return .down
        } else {
            return .up
        }
    }
    
}
