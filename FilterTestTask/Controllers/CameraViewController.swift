//
//  CameraViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 09.09.2022.
//

import UIKit
import AVKit

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { self.videoPreviewLayer.session }
        set { self.videoPreviewLayer.session = newValue }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewControllerDidStartRecording(_ controller: CameraViewController)
    func cameraViewController(_ controller: CameraViewController, didFinishRecordingWith outputURL: URL)
    func cameraViewController(_ controller: CameraViewController, recordingDidFailWith error: Error)
}


final class CameraViewController: UIViewController {
    private struct Device: Equatable {
        fileprivate enum Camera {
            fileprivate static let front: Device? = {
                guard let input = try? AVCaptureDeviceInput(device: .default(.builtInWideAngleCamera, for: .video, position: .front)!) else {
                    return nil
                }

                return .init(avCaptureDeviceInput: input)
            }()

            fileprivate static let back: Device? = {
                guard let input = try? AVCaptureDeviceInput(device: .default(.builtInWideAngleCamera, for: .video, position: .back)!) else {
                    return nil
                }

                return .init(avCaptureDeviceInput: input)
            }()
        }

        fileprivate enum Audio {
            fileprivate static let mic: Device? = {
                guard let input = try? AVCaptureDeviceInput(device: .default(for: .audio)!) else {
                    return nil
                }

                return .init(avCaptureDeviceInput: input)
            }()
        }

        fileprivate let avCaptureDeviceInput: AVCaptureDeviceInput
    }

    private struct State {
        let isRecording: Bool
        let camera: Device
        let output: AVCaptureMovieFileOutput
    }

    weak var delegate: CameraViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var currentState: State!

    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(.init(named: "close"), for: .normal)
        button.tintColor = .white
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        return button
    }()

    private let recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(.init(named: "record"), for: .normal)
        button.tintColor = .white
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        return button
    }()

    private let changeCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(.init(named: "change"), for: .normal)
        button.tintColor = .white
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        return button
    }()

    private var previewView: PreviewView { self.view as! PreviewView }

    override func loadView() {
        self.view = PreviewView()
        self.view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.closeButton.addTarget(self, action: #selector(closeButtonDidTap), for: .touchUpInside)
        self.view.addSubview(closeButton)

        self.recordButton.addTarget(self, action: #selector(recordButtonDidTap), for: .touchUpInside)
        self.view.addSubview(recordButton)

        self.changeCameraButton.addTarget(self, action: #selector(changeCameraButtonDidTap), for: .touchUpInside)
        self.view.addSubview(changeCameraButton)

        self.previewView.session = captureSession

        DispatchQueue.global(qos: .userInitiated).async {
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.closeButton.frame = CGRect(x: 20, y: self.view.safeAreaInsets.top + 40, width: 20, height: 20)

        self.recordButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.recordButton.center = CGPoint(x: self.view.bounds.width / 2, y: self.view.bounds.maxY - 100)

        self.changeCameraButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.changeCameraButton.center = CGPoint(x: self.view.bounds.width - 20 - 40, y: self.view.bounds.maxY - 100)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
        }
    }

    @objc
    private func closeButtonDidTap() {
        self.processStateChange(
            from: self.currentState,
            to: .init(isRecording: false, camera: self.currentState.camera, output: self.currentState.output)
        )
        self.dismiss(animated: true)
    }

    @objc
    private func recordButtonDidTap() {
        self.processStateChange(
            from: self.currentState,
            to: .init(
                isRecording: !self.currentState.isRecording,
                camera: self.currentState.camera,
                output: self.currentState.output
            )
        )
    }

    @objc
    private func changeCameraButtonDidTap() {
        guard let backCamera = Device.Camera.back, let frontCamera = Device.Camera.front else {
            return
        }

        let nextCamera = self.currentState.camera == backCamera ? frontCamera : backCamera
        self.processStateChange(
            from: self.currentState,
            to: .init(isRecording: false, camera: nextCamera, output: self.currentState.output)
        )
    }

    private func startRecording(state: State) {
        state.output.startRecording(to: .temporary(fileName: "recorded.mov"), recordingDelegate: self)
        self.delegate?.cameraViewControllerDidStartRecording(self)
    }

    private func stopRecording(state: State) {
        state.output.stopRecording()
    }

    private func processStateChange(from oldState: State?, to newState: State) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if let oldState = oldState {
            if oldState.camera != newState.camera {
                self.captureSession.removeInput(oldState.camera.avCaptureDeviceInput)
                self.captureSession.addInput(newState.camera.avCaptureDeviceInput)
            }

            if oldState.output != newState.output {
                self.captureSession.removeOutput(oldState.output)
                self.captureSession.addOutput(newState.output)
            }
        }

        if newState.isRecording {
            self.recordButton.setImage(.init(named: "stop"), for: .normal)
            self.recordButton.tintColor = .red
            self.startRecording(state: newState)
        } else {
            self.recordButton.setImage(.init(named: "record"), for: .normal)
            self.recordButton.tintColor = .white
            self.stopRecording(state: newState)
        }

        self.currentState = newState
    }

    private func setupCaptureSession() {
        self.captureSession.beginConfiguration()
        defer { self.captureSession.commitConfiguration() }

        guard
            let micDeviceInput = Device.Audio.mic?.avCaptureDeviceInput,
            self.captureSession.canAddInput(micDeviceInput)
        else {
            return
        }

        guard
            let backCamera = Device.Camera.back,
            self.captureSession.canAddInput(backCamera.avCaptureDeviceInput)
        else {
            return
        }

        let output = AVCaptureMovieFileOutput()
        guard self.captureSession.canAddOutput(output) else {
            return
        }

        self.captureSession.addInput(backCamera.avCaptureDeviceInput)
        self.captureSession.addInput(micDeviceInput)
        self.captureSession.addOutput(output)
        self.captureSession.sessionPreset = .hd1920x1080

        self.currentState = .init(isRecording: false, camera: backCamera, output: output)
    }

    private func setupCaptureObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionStarted),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
    }

    @objc func handleInterruptionStarted(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue)
        else {
            print("Failed to parse the interruption reason.")
            return
        }

        print(reason)
        self.captureSession.stopRunning()
    }

    @objc func handleInterruptionEnded(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue)
        else {
            print("Failed to parse the interruption reason.")
            return
        }

        print(reason)
        self.captureSession.startRunning()
    }

}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print(error)
            self.delegate?.cameraViewController(self, recordingDidFailWith: error)
            return
        }

        print("recording finished")
        self.delegate?.cameraViewController(self, didFinishRecordingWith: outputFileURL)
    }
}
