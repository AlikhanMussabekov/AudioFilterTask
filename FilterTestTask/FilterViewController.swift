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

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 50, height: 50)
        layout.scrollDirection = .horizontal

        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(ImageCollectionCell.self, forCellWithReuseIdentifier: ImageCollectionCell.reuseIdentifier)
        collection.backgroundColor = .clear
        collection.contentInset = .init(top: 0, left: 20, bottom: 0, right: 20)
        return collection
    }()

    private var renderedURL: URL?

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
        self.navigationItem.rightBarButtonItem = .init(
            title: "Share",
            style: .plain,
            target: self,
            action: #selector(shareButtonDidClick)
        )

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
        self.videoLayer.frame = self.view.bounds

        self.collectionView.frame = CGRect(
            origin: .init(x: 0, y: self.view.bounds.maxY - 100 - self.view.safeAreaInsets.bottom),
            size: .init(width: self.view.bounds.width, height: 100)
        )
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
                outputURL: .temporary(with: "filteredAudioFile.m4a"),
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
                                url: .temporary(with: "encodedVideo.mov"),
                                fileType: .mov,
                                preset: AVAssetExportPresetPassthrough
                            )
                        ) { result in
                            do {
                                let filteredVideoURL = try result.get()
                                self.renderedURL = filteredVideoURL
                                DispatchQueue.main.async {
                                    self.share(url: filteredVideoURL)
                                }
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

    @objc
    private func shareButtonDidClick() {
        guard let renderedURL = renderedURL else {
            return
        }

        self.share(url: renderedURL)
    }
}

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
