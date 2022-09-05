//
//  AVAsset.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import AVFoundation

extension AVAsset {
    enum ErrorKind: Error {
        case trackTypeNotFound
    }

    func firstTrack(with type: AVMediaType) throws -> AVAssetTrack {
        guard let track = self.tracks(withMediaType: .video).first else {
            throw ErrorKind.trackTypeNotFound
        }

        return track
    }

    var audioComposition: AVMutableComposition {
        get throws {
            let composition = AVMutableComposition()
            let firstVideoTrack = try self.firstTrack(with: .audio)
            try composition.apply(assetTrack: firstVideoTrack, with: .audio, in: range)
            return composition
        }
    }

    var videoComposition: AVMutableComposition {
        get throws {
            let composition = AVMutableComposition()
            let firstVideoTrack = try self.firstTrack(with: .video)
            try composition.apply(assetTrack: firstVideoTrack, with: .video, in: range)
            return composition
        }
    }

    var range: CMTimeRange {
        CMTimeRange(start: .zero, duration: self.duration)
    }
}
