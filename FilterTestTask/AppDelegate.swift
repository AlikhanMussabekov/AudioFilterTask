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
        window.rootViewController = RootViewController()
        window.makeKeyAndVisible()
        self.window = window

        return true
    }
}
