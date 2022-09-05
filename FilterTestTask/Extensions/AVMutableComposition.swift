//
//  AVMutableComposition.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import AVFoundation

extension AVMutableComposition {
    func apply(assetTrack: AVAssetTrack, with type: AVMediaType, in range: CMTimeRange) throws {
        let track = self.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid)
        try track?.insertTimeRange(range, of: assetTrack, at: .zero)
        track?.preferredTransform = assetTrack.preferredTransform
    }
}
