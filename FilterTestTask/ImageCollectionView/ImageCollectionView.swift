//
//  ImageCollectionView.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import UIKit

final class ImageCollectionView: UICollectionView {
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 40
        layout.itemSize = CGSize(width: 50, height: 50)
        layout.scrollDirection = .horizontal

        super.init(frame: .zero, collectionViewLayout: layout)

        self.register(ImageCollectionCell.self, forCellWithReuseIdentifier: ImageCollectionCell.reuseIdentifier)
        self.backgroundColor = .clear
        self.contentInset = .init(top: 0, left: 20, bottom: 0, right: 20)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
