//
//  CameraViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 09.09.2022.
//

import UIKit
import AVKit
import Photos
import MobileCoreServices

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
    func cameraViewController(_ controller: CameraViewController, didSelectGallery outputURL: URL)
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

    private let galleryButton: UIButton = {
        let button = UIButton(type: .custom)
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

        self.loadLastImageThumb(size: .init(width: 40, height: 40)) { image in
            if let image = image {
                self.galleryButton.setImage(image, for: .normal)
            } else {
                self.galleryButton.backgroundColor = .gray
            }
        }

        self.galleryButton.addTarget(self, action: #selector(galleryButtonDidTap), for: .touchUpInside)
        self.view.addSubview(galleryButton)

        self.recordButton.addTarget(self, action: #selector(recordButtonDidTap), for: .touchUpInside)
        self.view.addSubview(recordButton)

        self.changeCameraButton.addTarget(self, action: #selector(changeCameraButtonDidTap), for: .touchUpInside)
        self.view.addSubview(changeCameraButton)

        self.previewView.session = captureSession

        self.setupCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.galleryButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.galleryButton.center = CGPoint(x: 40, y: self.view.bounds.maxY - 100)

        self.recordButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.recordButton.center = CGPoint(x: self.view.bounds.width / 2, y: self.view.bounds.maxY - 100)

        self.changeCameraButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.changeCameraButton.center = CGPoint(x: self.view.bounds.width - 20 - 40, y: self.view.bounds.maxY - 100)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !self.captureSession.isRunning else { return }
        self.captureSession.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.captureSession.stopRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.captureSession.stopRunning()
    }

    private func loadLastImageThumb(size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let imgManager = PHImageManager.default()
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [.init(key: "creationDate", ascending: false)]

        guard let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions).lastObject else {
            completion(nil)
            return
        }

        let scale = UIScreen.main.scale
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast

        imgManager.requestImage(
            for: fetchResult,
            targetSize: scaledSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }

    @objc
    private func galleryButtonDidTap() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.delegate = self
        picker.allowsEditing = false
        self.present(picker, animated: true)
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
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

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

            DispatchQueue.main.async {
                if newState.isRecording {
                    self.recordButton.setImage(.init(named: "stop"), for: .normal)
                    self.recordButton.tintColor = .red
                    self.startRecording(state: newState)
                } else {
                    self.recordButton.setImage(.init(named: "record"), for: .normal)
                    self.recordButton.tintColor = .white
                    self.stopRecording(state: newState)
                }

                self.galleryButton.isHidden = newState.isRecording

                self.currentState = newState
            }
        }
    }

    private func setupCaptureSession() {
        self.captureSession.startRunning()
        self.captureSession.beginConfiguration()
        defer {
            self.captureSession.commitConfiguration()
        }

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

        guard self.captureSession.canSetSessionPreset(.hd1920x1080) else {
            return
        }

        self.captureSession.addInput(backCamera.avCaptureDeviceInput)
        self.captureSession.addInput(micDeviceInput)
        self.captureSession.addOutput(output)
        self.captureSession.sessionPreset = .hd1920x1080

        DispatchQueue.main.async {
            self.currentState = .init(isRecording: false, camera: backCamera, output: output)
        }
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

// MARK: - MediaChooseController + UIImagePickerControllerDelegate

extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        self.dismiss(animated: true) {
            if let mediaURL = info[.mediaURL] as? URL {
                self.delegate?.cameraViewController(self, didSelectGallery: mediaURL)
            }
        }
    }
}
