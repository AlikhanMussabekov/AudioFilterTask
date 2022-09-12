//
//  AppDelegate.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 04.09.2022.
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])

        let window = UIWindow()

        self.requestMediaAccess { granted in
            DispatchQueue.main.async {
                if granted {
                    window.rootViewController = CameraViewController()
                } else {
                    window.rootViewController = PermissionViewController()
                }

                window.makeKeyAndVisible()
                self.window = window
            }
        }

        return true
    }

    private func requestMediaAccess(completion: @escaping (Bool) -> Void) {
        self.requestCaptureAccess(for: .video) {
            $0 ? self.requestCaptureAccess(for: .audio) { completion($0) } : completion(false)
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


