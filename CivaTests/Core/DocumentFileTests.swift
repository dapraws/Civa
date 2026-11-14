//
//  DocumentFileTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 14/11/26.
//

import Foundation
import Testing
@testable import Civa

struct DocumentFileTests {
    /// A replaced document with the same file name drags out and previews its new contents.
    @Test func replacedContentsAreWrittenAgain() throws {
        let document = SupportingDocument(name: "CV", fileName: "cv-\(UUID()).pdf", data: Data("old".utf8), kind: .other)
        let first = try #require(document.fileURL())
        #expect(try Data(contentsOf: first) == Data("old".utf8))
        document.data = Data("newer".utf8)
        let second = try #require(document.fileURL())
        #expect(try Data(contentsOf: second) == Data("newer".utf8))
    }
}
