//
//  ApplicationBoardTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 19/11/26.
//

import Foundation
import Testing
@testable import Civa

@MainActor
struct ApplicationBoardTests {
    @Test func dropChangesStatus() throws {
        let grab = JobApplication(company: "Grab", position: "iOS Engineer", status: .applied)
        grab.updatedAt = .distantPast
        let moved = try #require(ApplicationBoard.move(grab.id.uuidString, to: .interview, in: [grab]))
        #expect(moved === grab)
        #expect(grab.status == .interview)
        #expect(grab.updatedAt > .distantPast)
    }

    @Test func dropOnItsOwnColumnChangesNothing() {
        let grab = JobApplication(company: "Grab", position: "iOS Engineer", status: .applied)
        grab.updatedAt = .distantPast
        #expect(ApplicationBoard.move(grab.id.uuidString, to: .applied, in: [grab]) == nil)
        #expect(grab.updatedAt == .distantPast)
    }

    @Test func dropOfUnknownItemIsIgnored() {
        let grab = JobApplication(company: "Grab", position: "iOS Engineer", status: .applied)
        #expect(ApplicationBoard.move("not an id", to: .offer, in: [grab]) == nil)
        #expect(ApplicationBoard.move(UUID().uuidString, to: .offer, in: [grab]) == nil)
        #expect(grab.status == .applied)
    }

    @Test func closedColumnsShowOnlyWhenAsked() {
        #expect(ApplicationBoard.statuses(showsClosed: false) == [.wishlist, .applied, .assessment, .interview, .offer])
        #expect(ApplicationBoard.statuses(showsClosed: true) == ApplicationStatus.allCases)
    }

    @Test func columnsGroupByStatusInListOrder() {
        let older = JobApplication(company: "Shopee", position: "iOS", applicationDate: .now - 86_400 * 5, status: .applied)
        let newer = JobApplication(company: "Spotify", position: "iOS", applicationDate: .now - 86_400 * 3, status: .applied)
        let rejected = JobApplication(company: "Bukalapak", position: "iOS", status: .rejected)

        let open = ApplicationBoard.columns([older, rejected, newer], showsClosed: false)
        #expect(open.map(\.status) == ApplicationBoard.statuses(showsClosed: false))
        #expect(open.first { $0.status == .applied }?.applications.map(\.company) == ["Spotify", "Shopee"])
        #expect(open.allSatisfy { $0.applications.allSatisfy { $0.status != .rejected } })

        let all = ApplicationBoard.columns([older, rejected, newer], showsClosed: true)
        #expect(all.first { $0.status == .rejected }?.applications.map(\.company) == ["Bukalapak"])
    }

    @Test func keyboardMovesToTheNeighboringColumn() {
        #expect(ApplicationBoard.neighbor(of: .applied, offset: 1, showsClosed: false) == .assessment)
        #expect(ApplicationBoard.neighbor(of: .applied, offset: -1, showsClosed: false) == .wishlist)
        #expect(ApplicationBoard.neighbor(of: .wishlist, offset: -1, showsClosed: false) == nil)
        #expect(ApplicationBoard.neighbor(of: .offer, offset: 1, showsClosed: false) == nil)
        #expect(ApplicationBoard.neighbor(of: .offer, offset: 1, showsClosed: true) == .rejected)
    }
}
