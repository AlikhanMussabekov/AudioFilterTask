//
//  ViewController.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 04.09.2022.
//

import Foundation
import UIKit
import MobileCoreServices
import AVFoundation

final class MediaChooseController: UIViewController {
    private let button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Choose video", for: .normal)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white

        self.button.addTarget(self, action: #selector(buttonDidTap), for: .touchUpInside)
        self.view.addSubview(button)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.button.frame = CGRect(origin: .zero, size: .init(width: 200, height: 44))
        self.button.center = self.view.center
    }

    // MARK: - Action

    @objc
    private func buttonDidTap(_ sender: UIButton) {
        let sheet = UIAlertController(title: "Select video", message: nil, preferredStyle: .actionSheet)

        let libraryAction: (UIAlertAction) -> Void = { _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [kUTTypeMovie as String]
            picker.delegate = self
            self.present(picker, animated: true)
        }

        let cameraAction: (UIAlertAction) -> Void = { _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = [kUTTypeMovie as String]
            picker.delegate = self
            self.present(picker, animated: true)
        }

        sheet.addAction(.init(title: "Library", style: .default, handler: libraryAction))

        if UIImagePickerController.isCameraDeviceAvailable(.rear) || UIImagePickerController.isCameraDeviceAvailable(.front) {
            sheet.addAction(.init(title: "Camera", style: .default, handler: cameraAction))
        }

        sheet.addAction(.init(title: "Cancel", style: .cancel))

        self.present(sheet, animated: true)
    }
}

// MARK: - MediaChooseController + UIImagePickerControllerDelegate

extension MediaChooseController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        self.dismiss(animated: true) {
            if let mediaURL = info[.mediaURL] as? URL {
                let mediaAsset = AVAsset(url: mediaURL)
                let filterController = FilterViewController(asset: mediaAsset)
                self.navigationController?.pushViewController(filterController, animated: true)
            }
        }
    }
}
