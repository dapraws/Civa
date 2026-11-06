//
//  YearMonthTests.swift
//  CivaTests
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Testing
@testable import Civa

struct YearMonthTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    @Test func ordersByYearThenMonthWithYearOnlyFirst() {
        let dates = [
            YearMonth(year: 2025, month: 3),
            YearMonth(year: 2024, month: 12),
            YearMonth(year: 2025),
            YearMonth(year: 2025, month: 1),
        ]
        #expect(dates.sorted() == [
            YearMonth(year: 2024, month: 12),
            YearMonth(year: 2025),
            YearMonth(year: 2025, month: 1),
            YearMonth(year: 2025, month: 3),
        ])
    }

    @Test func formatsMonthAndYear() {
        #expect(YearMonth(year: 2025, month: 3).formatted(calendar: calendar) == "Mar 2025")
        #expect(YearMonth(year: 2025).formatted(calendar: calendar) == "2025")
    }

    @Test func formatsRanges() {
        let start = YearMonth(year: 2024, month: 3)
        let end = YearMonth(year: 2025)
        #expect(YearMonth.rangeText(start: start, end: end, calendar: calendar) == "Mar 2024 – 2025")
        #expect(YearMonth.rangeText(start: start, end: end, isCurrent: true, calendar: calendar) == "Mar 2024 – Present")
        #expect(YearMonth.rangeText(start: nil, end: end, calendar: calendar) == "2025")
        #expect(YearMonth.rangeText(start: nil, end: nil, calendar: calendar).isEmpty)
    }

    @Test func currentAndUndatedRecordsSortNewest() {
        let past = YearMonth.recency(start: YearMonth(year: 2020), end: YearMonth(year: 2022))
        let current = YearMonth.recency(start: YearMonth(year: 2019), end: nil, isCurrent: true)
        let undated = YearMonth.recency(start: nil, end: nil)
        #expect(past < current)
        #expect(current == undated)
    }
}
