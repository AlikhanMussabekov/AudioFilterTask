//
//  URL.swift
//  FilterTestTask
//
//  Created by A.Musabekov on 05.09.2022.
//

import Foundation

extension URL {
    static func temporary(with fileName: String) -> URL {
        Self(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }
}
