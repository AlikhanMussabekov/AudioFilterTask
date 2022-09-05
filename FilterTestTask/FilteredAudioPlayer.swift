//
//  FilteredAudioPlayer.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import AVKit

final class FilteredAudioPlayer {
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

    // swiftlint:disable:next force_unwrap
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!

    init() {
        self.engine.attach(self.audioPlayer)
        self.engine.attach(self.pitchControl)
        self.engine.attach(self.speedControl)

        self.engine.connect(self.audioPlayer, to: self.speedControl, format: self.format)
        self.engine.connect(self.speedControl, to: self.pitchControl, format: self.format)
        self.engine.connect(self.pitchControl, to: self.engine.mainMixerNode, format: self.format)
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

    func apply() {
        // TODO: - filter applying
    }
}