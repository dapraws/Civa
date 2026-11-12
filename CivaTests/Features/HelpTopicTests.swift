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
        #expect(ids("harvard") == ["format", "ovi"])
        #expect(ids("SKILLS").contains("skills"))
        #expect(ids("zzzz").isEmpty)
        #expect(Set(HelpTopic.all.map(\.id)).count == HelpTopic.all.count)
    }

    @Test func oviTopicCoversEveryTip() throws {
        let topic = try #require(HelpTopic.all.first { $0.id == "ovi" })
        #expect(topic.sections.count == OviTipID.allCases.count + 1)  // an intro, then one per tip
        for section in topic.sections.dropFirst() {
            #expect(section.text.contains("Source:"), "\(section.heading) names no source")
        }
    }
}
