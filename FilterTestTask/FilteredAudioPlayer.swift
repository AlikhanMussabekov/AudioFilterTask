//
//  FilteredAudioPlayer.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import AVKit

final class FilteredAudioPlayer {
    struct PresetConfiguration {
        struct Distortion {
            var value: Float = -6
            var mix: Float = 0
        }

        let pitch: Float
        let reverb: Float
        let distortion: Distortion
        let speed: Float

        let image: UIImage?

        init(pitch: Float = 0, reverb: Float = 0, distortion: Distortion = .init(), speed: Float = 1, image: UIImage?) {
            self.pitch = pitch
            self.reverb = reverb
            self.distortion = distortion
            self.speed = speed
            self.image = image
        }
    }

    let presets: [PresetConfiguration] = [
        .init(pitch: -100, speed: 0.9, image: "👨🏻".toImage()),
        .init(pitch: 300, speed: 1.1, image: "👧🏻".toImage()),
        .init(pitch: -600, distortion: .init(value: -20, mix: 40), image: "🤖".toImage()),
        .init(pitch: 0, reverb: 20, image: "🏠".toImage()),
        .init(pitch: 900, image: "🐹".toImage())
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

    init() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.nodes.forEach(self.engine.attach)

            var previousNode = self.nodes.first! // swiftlint:disable:this force_unwrap
            var engineNodes = self.nodes
            engineNodes.append(self.engine.mainMixerNode)
            engineNodes.removeFirst()

            var iterator = engineNodes.makeIterator()
            while let next = iterator.next() {
                self.engine.connect(previousNode, to: next, format: self.format)
                previousNode = next
            }

            self.apply(preset: .init(image: nil))
        }
    }

    func play(url: URL, recordingConfiguration: RecordingConfiguration) throws {
        let audioFile = try AVAudioFile(forReading: url)

        if recordingConfiguration.enabled {
            var filteredAudioFile: AVAudioFile? = try AVAudioFile(
                forWriting: recordingConfiguration.outputURL,
                settings: self.format.settings
            )

            engine.mainMixerNode.installTap(
                onBus: 0,
                bufferSize: 4096,
                format: self.format
            ) { [weak self] buffer, time in
                guard let self = self else { return }

                guard
                    let filteredAudioFileLength = filteredAudioFile?.length,
                    filteredAudioFileLength <= audioFile.length
                else {
                    self.engine.mainMixerNode.removeTap(onBus: 0)
                    filteredAudioFile = nil // flush AVAudioFile(forWriting:) для m4a
                    recordingConfiguration.completion(recordingConfiguration.outputURL)
                    return
                }

                try? filteredAudioFile?.write(from: buffer)
            }
        }

        self.audioPlayer.scheduleFile(audioFile, at: nil)

        self.engine.prepare()
        try self.engine.start()
        self.audioPlayer.play()
    }

    func apply(preset: PresetConfiguration) {
        self.pitchControl.pitch = preset.pitch
        self.reverbControl.wetDryMix = preset.reverb
        self.distortionControl.preGain = preset.distortion.value
        self.distortionControl.wetDryMix = preset.distortion.mix
        self.speedControl.rate = preset.speed
    }
}
