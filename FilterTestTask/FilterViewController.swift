//
//  FilterViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 04.09.2022.
//

import UIKit
import AVKit

final class FilterViewController: UIViewController {
    private let mediaAsset: AVAsset

    private let filteredAudioPlayer = FilteredAudioPlayer()
    private let videoLayer = AVPlayerLayer()
    private let assetExporter = AssetExporter()

    override var prefersStatusBarHidden: Bool {
        true
    }

    init(asset: AVAsset) {
        self.mediaAsset = asset
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        self.view.layer.insertSublayer(self.videoLayer, at: 0)

        do {
            try self.process()
        } catch {
            print(error)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.videoLayer.frame = self.view.bounds
    }

    private func process() throws {
        let videoComposition = try self.mediaAsset.videoComposition
        let audioComposition = try self.mediaAsset.audioComposition

        self.assetExporter.export(
            asset: audioComposition,
            with: .init(
                url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audioTrack.m4a"),
                fileType: .m4a,
                preset: AVAssetExportPresetAppleM4A
            )
        ) { [weak self] result in
            guard let self = self else { return }

            do {
                let url = try result.get()
                try self.play(video: videoComposition, audio: url)
            } catch {
                print(error)
            }
        }
    }

    private func play(video: AVMutableComposition, audio: URL) throws {
        try self.playVideo(asset: video)
        try self.filteredAudioPlayer.play(
            url: audio,
            recordingConfiguration: .init(
                enabled: true,
                outputURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("filteredAudioFile.m4a"),
                completion: { [weak self] filteredAudioFileURL in
                    guard let self = self else { return }

                    let filteredAudioAsset = AVAsset(url: filteredAudioFileURL)
                    guard let filteredAudioAssetTrack = filteredAudioAsset.tracks(withMediaType: .audio).first else {
                        return
                    }

                    do {
                        try video.apply(assetTrack: filteredAudioAssetTrack, with: .audio, in: video.range)
                        self.assetExporter.export(
                            asset: video,
                            with: .init(
                                url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("encodedVideo.mov"),
                                fileType: .mov,
                                preset: AVAssetExportPresetPassthrough
                            )
                        ) { result in
                            do {
                                let filteredVideoURL = try result.get()
                                self.share(url: filteredVideoURL)
                            } catch {
                                print(error)
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
            )
        )
    }

    private func playVideo(asset: AVAsset) throws {
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)

        self.videoLayer.player = player
        player.play()
    }

    private func share(url: URL) {
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(activityController, animated: true)
    }
}
