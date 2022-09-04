//
//  FilterViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 04.09.2022.
//

import Foundation
import UIKit
import AVFoundation
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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        self.slider.minimumValue = -2400
        self.slider.maximumValue = 2400
        self.slider.value = 0
        self.view.addSubview(self.slider)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            // report for an error
            print(error)
        }

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

        let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("audioTrack.m4a")
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            try? FileManager.default.removeItem(atPath: outputUrl.path)
        }

        let exportSession = AVAssetExportSession(asset: audioComposition, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputFileType = AVFileType.m4a
        exportSession.outputURL = outputUrl

        exportSession.exportAsynchronously {
            guard case exportSession.status = AVAssetExportSession.Status.completed else { return }

            DispatchQueue.main.async {
                guard let outputURL = exportSession.outputURL else { return }

                do {
                    try self.playVideo(asset: videoComposition)
                    try self.playAudio(url: outputURL) { url in
                        DispatchQueue.main.async {
                            let filteredAudio = AVAsset(url: url)
                            filteredAudio.loadValuesAsynchronously(forKeys: ["tracks"]) {
                                guard let filteredAudioAsset = filteredAudio.tracks(withMediaType: .audio).first else {
                                    return
                                }

                                let filteredAudioTrack = videoComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

                                do {
                                    try filteredAudioTrack?.insertTimeRange(range, of: filteredAudioAsset, at: .zero)
                                    filteredAudioTrack?.preferredTransform = filteredAudioAsset.preferredTransform

                                    encodeVideo(from: videoComposition) { result in
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
                    }
                } catch {
                    print(error)
                }
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
            format: audioFile.processingFormat
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

enum ErrorKind: Error {
    case urlIsNil
    case encodingFailed
    case unknown
}

func encodeVideo(from composition: AVComposition, completionHandler: @escaping (Result<URL, Error>) -> Void) {
    let urlOut = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("encodedVideo.mov")

    if FileManager.default.fileExists(atPath: urlOut.path) {
        do {
            try FileManager.default.removeItem(at: urlOut)
        } catch {
            completionHandler(.failure(error))
        }
    }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
        completionHandler(.failure(ErrorKind.encodingFailed))
        return
    }

    exportSession.outputURL = urlOut
    exportSession.outputFileType = AVFileType.mov

    let start: CMTime = .zero
    let range = CMTimeRangeMake(start: start, duration: composition.duration)
    exportSession.timeRange = range

    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            if let url = exportSession.outputURL {
                completionHandler(.success(url))
            } else {
                completionHandler(.failure(ErrorKind.encodingFailed))
            }
        default:
            completionHandler(.failure(ErrorKind.encodingFailed))
        }
    }
}
