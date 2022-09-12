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
    private let collectionView = ImageCollectionView()

    private var filteredMedia: AVMutableComposition?

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        self.view.layer.insertSublayer(self.videoLayer, at: 0)

        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.view.addSubview(self.collectionView)

        do {
            try self.process()
        } catch {
            print(error)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.videoLayer.frame = CGRect(
            x: 0,
            y: self.view.safeAreaInsets.top,
            width: self.view.bounds.width,
            height: self.view.bounds.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom
        )

        self.collectionView.frame = CGRect(
            origin: .init(x: 0, y: self.view.bounds.maxY - 100 - self.view.safeAreaInsets.bottom),
            size: .init(width: self.view.bounds.width, height: 100)
        )
    }

    // MARK: - Media rocessing

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

    // MARK: - Playback

    private func play(video: AVMutableComposition, audio: URL) throws {
        try self.playVideo(asset: video)
        try self.filteredAudioPlayer.play(
            url: audio,
            recordingConfiguration: .init(
                enabled: true,
                outputURL: .temporary(fileName: "filteredAudioFile.m4a"),
                completion: { [weak self] filteredAudioFileURL in
                    guard let self = self else { return }
                    self.finish(video: video, filteredAudio: filteredAudioFileURL)
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

    private func finish(video: AVMutableComposition, filteredAudio url: URL) {
        let filteredAudioAsset = AVAsset(url: url)
        guard let filteredAudioAssetTrack = filteredAudioAsset.tracks(withMediaType: .audio).first else {
            return
        }

        do {
            try video.apply(assetTrack: filteredAudioAssetTrack, with: .audio, in: video.range)
            self.filteredMedia = video

            DispatchQueue.main.async {
                self.navigationItem.rightBarButtonItem = .init(
                    title: "Share",
                    style: .plain,
                    target: self,
                    action: #selector(self.shareButtonDidClick)
                )
            }
        } catch {
            print(error)
        }
    }

    // MARK: - Sharing

    @objc
    private func shareButtonDidClick() {
        guard let filteredMedia = filteredMedia else {
            return
        }

        LoadingHUD.show()

        self.assetExporter.export(
            asset: filteredMedia,
            with: .init(
                url: .temporary(fileName: "encodedVideo.mov"),
                fileType: .mov,
                preset: AVAssetExportPresetPassthrough
            )
        ) { result in
            DispatchQueue.main.async {
                LoadingHUD.hide()
            }

            do {
                let filteredVideoURL = try result.get()
                DispatchQueue.main.async {
                    self.share(url: filteredVideoURL)
                }
            } catch {
                print(error)
            }
        }
    }

    private func share(url: URL) {
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(activityController, animated: true)
    }
}

// MARK: - FilterViewController + CollectionView

extension FilterViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ImageCollectionCell.reuseIdentifier,
                for: indexPath
            ) as? ImageCollectionCell
        else {
            fatalError()
        }

        cell.image = self.filteredAudioPlayer.presets[indexPath.row].image
        return cell
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.filteredAudioPlayer.presets.count
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedPreset = self.filteredAudioPlayer.presets[indexPath.row]
        self.filteredAudioPlayer.apply(preset: selectedPreset)
    }
}
