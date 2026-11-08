//
//  HelpTopicTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Testing
@testable import Civa

/// Help search finds a page by its title or anything on it.
@MainActor
struct HelpTopicTests {
    @Test func searchMatchesTitlesAndText() {
        let ids = { (query: String) in HelpTopic.all.filter { $0.matches(query) }.map(\.id) }
        #expect(ids("").count == HelpTopic.all.count)
        #expect(ids("harvard") == ["format"])
        #expect(ids("SKILLS").contains("skills"))
        #expect(ids("zzzz").isEmpty)
        #expect(Set(HelpTopic.all.map(\.id)).count == HelpTopic.all.count)
    }
}
