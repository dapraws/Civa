//
//  PageHeaderTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import AppKit
import SwiftUI
import Testing
@testable import Civa

@MainActor
struct PageHeaderTests {
    @MainActor final class Box {
        var action: PageAction?
    }

    @Test func addActionReachesHeader() {
        let box = Box()
        let view = Text("Records")
            .pageAction(PageAction(id: "experience", title: "Add Experience", systemImage: "plus", shortcut: "n") {})
            .onPreferenceChange(PageActionKey.self) { value in
                MainActor.assumeIsolated { box.action = value }
            }
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        host.layout()
        #expect(box.action?.title == "Add Experience")
    }

    @Test func pageActionEquality() {
        let a = PageAction(id: "x", title: "Add", systemImage: nil, shortcut: nil) {}
        let b = PageAction(id: "x", title: "Add", systemImage: "plus", shortcut: "n") { print("other") }
        let c = PageAction(id: "y", title: "Add", systemImage: nil, shortcut: nil) {}
        #expect(a == b)
        #expect(a != c)
    }
}
