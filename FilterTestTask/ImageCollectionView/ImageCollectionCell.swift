//
//  ImageCollectionCell.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import UIKit

final class ImageCollectionCell: UICollectionViewCell {
    var image: UIImage? {
        get { self.imageView.image }
        set { self.imageView.image = newValue }
    }

    override var isSelected: Bool {
        didSet {
            self.transform = isSelected ? CGAffineTransform(scaleX: 1.5, y: 1.5) : .identity
        }
    }

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(self.imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.contentView.bounds
    }
}
