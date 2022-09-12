//
//  PermissionViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 13.09.2022.
//

import UIKit

final class PermissionViewController: UIViewController {
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Enable video and microphone access in settings"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let openSettingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Open settings", for: .normal)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black
        self.view.addSubview(label)

        self.openSettingsButton.addTarget(self, action: #selector(openSettingsButtonDidTap), for: .touchUpInside)
        self.view.addSubview(openSettingsButton)
        self.setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),

            openSettingsButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            openSettingsButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20)
        ])
    }

    @objc
    private func openSettingsButtonDidTap() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
