//
//  String+extension.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import Foundation

extension String {
    func writeToTemporaryFile(named name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
