//
//  FilterViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 04.09.2022.
//

import UIKit
import AVKit

final class FilterViewController: UIViewController {
    private let mediaURL: URL

    let engine = AVAudioEngine()
    let audioPlayer = AVAudioPlayerNode()
    let speedControl = AVAudioUnitVarispeed()
    let pitchControl = AVAudioUnitTimePitch()
    let distortionControl = AVAudioUnitDistortion()

    let slider = UISlider()

    let retryButton: UIButton = {
        let button = UIButton(type: .custom)

        return button
    }()

    init(mediaURL: URL) {
        self.mediaURL = mediaURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.slider.frame = CGRect(origin: .zero, size: .init(width: 200, height: 30))
        self.slider.center = CGPoint(x: self.view.center.x, y: self.view.frame.maxY - self.view.safeAreaInsets.bottom - 40)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        self.slider.minimumValue = -2400
        self.slider.maximumValue = 2400
        self.slider.value = 0
        self.view.addSubview(self.slider)


        let initialVideoAsset = AVAsset(url: self.mediaURL)
        let range = CMTimeRange(start: .zero, duration: initialVideoAsset.duration)

        let videoComposition = AVMutableComposition()
        let videoTrack = videoComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        guard let videoAsset = initialVideoAsset.tracks(withMediaType: .video).first else {
            return
        }

        do {
            try videoTrack?.insertTimeRange(range, of: videoAsset, at: .zero)
            videoTrack?.preferredTransform = videoAsset.preferredTransform
        } catch {
            print(error)
        }

        let audioComposition = AVMutableComposition()
        let audioTrack = audioComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        guard let audioAsset = initialVideoAsset.tracks(withMediaType: .audio).first else {
            return
        }

        do {
            try audioTrack?.insertTimeRange(range, of: audioAsset, at: .zero)
            audioTrack?.preferredTransform = audioAsset.preferredTransform
        } catch {
            print(error)
        }

        let assetExporter = AssetExporter()
        assetExporter.export(
            asset: audioComposition,
            with: .init(
                url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audioTrack.m4a"),
                fileType: .m4a,
                preset: AVAssetExportPresetAppleM4A
            )
        ) { result in
            do {
                let url = try result.get()

                try self.playVideo(asset: videoComposition)
                try self.playAudio(url: url) { url in
                    let filteredAudio = AVAsset(url: url)
                    filteredAudio.loadValuesAsynchronously(forKeys: ["tracks"]) {
                        guard let filteredAudioAsset = filteredAudio.tracks(withMediaType: .audio).first else {
                            return
                        }

                        let filteredAudioTrack = videoComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

                        do {
                            try filteredAudioTrack?.insertTimeRange(range, of: filteredAudioAsset, at: .zero)
                            filteredAudioTrack?.preferredTransform = filteredAudioAsset.preferredTransform

                            assetExporter.export(
                                asset: videoComposition,
                                with: .init(
                                    url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("encodedVideo.mov"),
                                    fileType: .mov,
                                    preset: AVAssetExportPresetPassthrough
                                )
                            ) { result in
                                do {
                                    let filteredVideoURL = try result.get()
                                    let activityController = UIActivityViewController(activityItems: [filteredVideoURL], applicationActivities: nil)
                                    DispatchQueue.main.async {
                                        self.present(activityController, animated: true)
                                    }
                                } catch {
                                    print(error)
                                }
                            }
                        } catch {
                            print(error)
                        }
                    }
                }
            } catch {
                print(error)
            }
        }
    }

    private func playVideo(asset: AVAsset) throws {
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false

        self.addChild(controller)
        self.view.insertSubview(controller.view, at: 0)

        player.play()
    }

    private func playAudio(url: URL, completion: @escaping (URL) -> Void) throws {
        let audioFile = try AVAudioFile(forReading: url)
        guard let stereoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false) else {
            return
        }

        engine.attach(audioPlayer)
        engine.attach(pitchControl)
        engine.attach(speedControl)

        engine.connect(audioPlayer, to: speedControl, format: stereoFormat)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)

        let filteredAudioFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("filteredAudioFile.m4a")
        var filteredAudioFile: AVAudioFile? = try AVAudioFile(forWriting: filteredAudioFileURL, settings: stereoFormat.settings)

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: stereoFormat
        ) { [weak self] buffer, time in
            guard let self = self else { return }

            guard filteredAudioFile!.length <= audioFile.length else {
                self.engine.mainMixerNode.removeTap(onBus: 0)
                filteredAudioFile = nil
                completion(filteredAudioFileURL)
                return
            }

            do {
                try filteredAudioFile?.write(from: buffer)
            } catch {
                print(error)
            }
        }

        audioPlayer.scheduleFile(audioFile, at: nil)

        engine.prepare()

        try engine.start()
        audioPlayer.play()
    }

    @objc
    private func sliderValueChanged(_ sender: UISlider) {
        self.pitchControl.pitch = sender.value
    }
}
