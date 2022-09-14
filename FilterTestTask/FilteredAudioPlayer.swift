//
//  FilteredAudioPlayer.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import AVKit

final class FilteredAudioPlayer {
    struct PresetConfiguration {
        static let `default` = Self()
        private static let cache = NSCache<NSString, UIImage>()

        struct Distortion {
            var value: Float = -6
            var mix: Float = 0
        }

        let pitch: Float
        let reverb: Float
        let distortion: Distortion
        let speed: Float
        let emoji: String?

        init(pitch: Float = 0, reverb: Float = 0, distortion: Distortion = .init(), speed: Float = 1, emoji: String? = nil) {
            self.pitch = pitch
            self.reverb = reverb
            self.distortion = distortion
            self.speed = speed
            self.emoji = emoji
        }

        func requestImage(completion: @escaping (UIImage?) -> Void) {
            guard let emoji = emoji else {
                completion(nil)
                return
            }

            if let image = Self.cache.object(forKey: NSString(string: emoji)) {
                completion(image)
                return
            }

            DispatchQueue.global(qos: .background).async {
                guard let image = self.emoji?.toImage() else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                Self.cache.setObject(image, forKey: NSString(string: emoji))
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }

    lazy var presets: [PresetConfiguration] = [
        .init(pitch: -100, speed: 0.9, emoji: "👨🏻"),
        .init(pitch: 300, speed: 1.1, emoji: "👧🏻"),
        .init(pitch: -600, distortion: .init(value: -20, mix: 40), emoji: "🤖"),
        .init(pitch: 0, reverb: 20, emoji: "🏠"),
        .init(pitch: 900, emoji: "🐹")
    ]

    struct RecordingConfiguration {
        typealias Completion = (URL) -> Void

        let enabled: Bool
        let outputURL: URL
        let completion: Completion

        init(enabled: Bool = false, outputURL: URL, completion: @escaping Completion) {
            self.enabled = enabled
            self.outputURL = outputURL
            self.completion = completion
        }
    }

    private let engine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let speedControl = AVAudioUnitVarispeed()
    private let pitchControl = AVAudioUnitTimePitch()
    private let distortionControl = AVAudioUnitDistortion()
    private let reverbControl = AVAudioUnitReverb()

    private var nodes: [AVAudioNode] { [audioPlayer, speedControl, pitchControl, distortionControl, reverbControl] }

    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!

    private var playingAudioFile: AVAudioFile?
    private var filteredAudioFile: AVAudioFile?

    private var renderingManually = false

    init() {
        self.nodes.forEach(self.engine.attach)

        var previousNode = self.nodes.first!
        var engineNodes = self.nodes
        engineNodes.append(self.engine.mainMixerNode)
        engineNodes.removeFirst()

        var iterator = engineNodes.makeIterator()
        while let next = iterator.next() {
            self.engine.connect(previousNode, to: next, format: self.format)
            previousNode = next
        }

        self.apply(preset: .default)
    }

    func play(url: URL, recordingConfiguration: RecordingConfiguration) throws {
        let audioFile = try AVAudioFile(forReading: url)

        if recordingConfiguration.enabled {
            var filteredAudioFile: AVAudioFile? = try AVAudioFile(
                forWriting: recordingConfiguration.outputURL,
                settings: self.format.settings
            )
            self.filteredAudioFile = filteredAudioFile

            self.engine.mainMixerNode.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: self.format
            ) { [weak self] buffer, time in
                guard let self = self, !self.renderingManually else { return }

                guard
                    let filteredAudioFileLength = filteredAudioFile?.length,
                    filteredAudioFileLength <= audioFile.length
                else {
                    DispatchQueue.global(qos: .userInteractive).async {
                        self.engine.mainMixerNode.removeTap(onBus: 0)
                        filteredAudioFile = nil // flush AVAudioFile(forWriting:) для m4a

                        DispatchQueue.main.async {
                            recordingConfiguration.completion(recordingConfiguration.outputURL)
                        }
                    }
                    return
                }

                try? filteredAudioFile?.write(from: buffer)
            }
        }

        self.audioPlayer.scheduleFile(audioFile, at: nil)

        self.engine.prepare()
        try self.engine.start()
        self.audioPlayer.play()

        self.playingAudioFile = audioFile
    }

    func renderManually(completion: @escaping (URL) -> Void) {
        guard
            let playingAudioFile = self.playingAudioFile,
            let filteredAudioFile = self.filteredAudioFile
        else {
            return
        }

        self.renderingManually = true

        DispatchQueue.global(qos: .userInteractive).async {
            do {
                self.audioPlayer.pause()
                self.engine.stop()

                try self.engine.enableManualRenderingMode(.offline, format: self.format, maximumFrameCount: 4096)

                self.engine.prepare()
                try self.engine.start()
                self.audioPlayer.play()

                let buffer = AVAudioPCMBuffer(
                    pcmFormat: self.engine.manualRenderingFormat,
                    frameCapacity: self.engine.manualRenderingMaximumFrameCount
                )!

                while filteredAudioFile.length < playingAudioFile.length {
                    let frameCount = playingAudioFile.length - filteredAudioFile.length
                    let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)

                    switch try self.engine.renderOffline(framesToRender, to: buffer) {
                    case .success:
                        try filteredAudioFile.write(from: buffer)
                    default:
                        break
                    }
                }

                self.audioPlayer.stop()
                self.engine.stop()

                DispatchQueue.main.async {
                    self.filteredAudioFile = nil
                    completion(filteredAudioFile.url)
                    self.renderingManually = false
                }
            } catch {
                print(error)
            }
        }
    }

    func stop() {
        self.engine.stop()
        self.audioPlayer.stop()
    }

    func apply(preset: PresetConfiguration) {
        self.pitchControl.pitch = preset.pitch
        self.reverbControl.wetDryMix = preset.reverb
        self.distortionControl.preGain = preset.distortion.value
        self.distortionControl.wetDryMix = preset.distortion.mix
        self.speedControl.rate = preset.speed
    }
}
