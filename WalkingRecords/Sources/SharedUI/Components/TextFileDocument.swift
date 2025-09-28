//
//  TextFileDocument.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import UniformTypeIdentifiers
import Foundation
import SwiftUI

struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText]

    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        throw NSError(domain: "Unsupported", code: -1)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url else {
            fatalError("Missing URL")
        }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}
