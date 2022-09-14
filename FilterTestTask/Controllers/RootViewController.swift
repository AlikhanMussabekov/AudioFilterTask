//
//  RootViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 15.09.2022.
//

import UIKit
import AVFoundation

final class RootViewController: UIViewController {

    private weak var currentViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.requestMediaAccess { [weak self] granted in
            guard let self = self else { return }

            if granted {
                self.presentCamera()
            } else {
                self.presentPermissionNeeded()
            }
        }
    }

    // MARK: - View controller presentations

    private func presentPermissionNeeded() {
        let vc = PermissionViewController()
        self.show(vc)
    }

    private func presentCamera() {
        let vc = CameraViewController()
        vc.delegate = self
        self.show(vc)
    }

    private func presentFilterController(with url: URL) {
        let mediaAsset = AVAsset(url: url)
        let filterController = FilterViewController(asset: mediaAsset)
        filterController.delegate = self
        self.show(UINavigationController(rootViewController: filterController))
    }

    private func show(_ viewController: UIViewController) {
        let currentViewController = self.currentViewController

        currentViewController?.willMove(toParent: nil)
        currentViewController?.beginAppearanceTransition(false, animated: true)

        viewController.beginAppearanceTransition(true, animated: true)
        viewController.willMove(toParent: self)

        self.view.addSubview(viewController.view)
        viewController.view.frame = self.view.bounds

        UIView.transition(with: self.view, duration: 0.3, options: [.beginFromCurrentState, .transitionCrossDissolve]) {
            self.addChild(viewController)
            currentViewController?.removeFromParent()
            currentViewController?.view.removeFromSuperview()
        } completion: { completed in
            if completed {
                currentViewController?.didMove(toParent: nil)
                currentViewController?.endAppearanceTransition()

                viewController.didMove(toParent: self)
                viewController.endAppearanceTransition()

                self.currentViewController = viewController
            }
        }
    }

    // MARK: - Media permissions

    private func requestMediaAccess(completion: @escaping (Bool) -> Void) {
        func complete(_ granted: Bool) {
            DispatchQueue.main.async {
                completion(granted)
            }
        }

        self.requestCaptureAccess(for: .video) {
            $0 ? self.requestCaptureAccess(for: .audio, completion: complete) : complete(false)
        }
    }

    private func requestCaptureAccess(for mediaType: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType, completionHandler: completion)
        default:
            completion(false)
        }
    }
}

extension RootViewController: CameraViewControllerDelegate {
    func cameraViewControllerDidStartRecording(_ controller: CameraViewController) {
        print("Recording started")
    }

    func cameraViewController(_ controller: CameraViewController, didFinishRecordingWith outputURL: URL) {
        self.presentFilterController(with: outputURL)
    }

    func cameraViewController(_ controller: CameraViewController, recordingDidFailWith error: Error) {
        print("Recording failed with error: \(error)")
    }

    func cameraViewController(_ controller: CameraViewController, didSelectGallery outputURL: URL) {
        self.presentFilterController(with: outputURL)
    }
}

extension RootViewController: FilterViewControllerDelegate {
    func filterViewControllerDidCancel(_ filterController: FilterViewController) {
        self.presentCamera()
    }

    func filterViewController(_ filterController: FilterViewController, needsShare url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(activityViewController, animated: true)
    }
}
