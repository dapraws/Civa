//
//  ArrayMoveTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Testing
@testable import Civa

struct ArrayMoveTests {
    struct Item: Identifiable, Equatable { let id: Int }

    @Test func movesOnePlaceAndStopsAtTheEnds() {
        var items = [Item(id: 1), Item(id: 2), Item(id: 3)]
        items.move(id: 3, by: -1)
        #expect(items.map(\.id) == [1, 3, 2])
        items.move(id: 1, by: -1)
        #expect(items.map(\.id) == [1, 3, 2])
        items.move(id: 2, by: 1)
        #expect(items.map(\.id) == [1, 3, 2])
    }
}
