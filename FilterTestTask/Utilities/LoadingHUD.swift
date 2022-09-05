//
//  LoadingHUD.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import UIKit

private class HUDWindow: UIWindow {
    fileprivate let hud: LoadingHUD

    init(with hud: LoadingHUD) {
        self.hud = hud
        super.init(frame: .zero)
        self.addSubview(hud)
        self.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.hud.frame = CGRect(origin: .zero, size: .init(width: 100, height: 100))
        self.hud.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
    }
}

final class LoadingHUD: UIView {
    private static var window: UIWindow?

    static func show() {
        guard window == nil else {
            return
        }

        let hud = LoadingHUD()
        let window = HUDWindow(with: hud)
        window.frame = UIApplication.shared.keyWindow?.bounds ?? .zero
        window.makeKeyAndVisible()

        hud.start()
        Self.window = window
    }

    static func hide() {
        Self.window?.resignKey()
        Self.window = nil
    }

    private let activityIndicator = UIActivityIndicatorView(frame: .zero)

    private init() {
        super.init(frame: .zero)
        self.activityIndicator.color = .white
        self.addSubview(self.activityIndicator)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.activityIndicator.frame = CGRect(origin: .zero, size: .init(width: 100, height: 100))
        self.activityIndicator.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
    }

    private func start() {
        self.activityIndicator.startAnimating()
    }

    private func stop() {
        self.activityIndicator.stopAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
