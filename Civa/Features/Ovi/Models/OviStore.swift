//
//  OviStore.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 12/11/26.
//

import Foundation

/// What Ovi remembers about one tip (tip engine spec §6).
struct OviTipRecord: Codable, Equatable {
    enum Outcome: String, Codable {
        case shown, closed, acted, fixed
    }

    var lastShown: Date?
    var snoozedUntil: Date?
    var isEnded = false
    var lastOutcome: Outcome = .shown
}

/// Ovi's per-Mac state in `UserDefaults`, never SwiftData: it isn't career data, so it never
/// reaches resumes, exports, snapshots or Claude. Unknown tip IDs and corrupt JSON are ignored.
final class OviStore {
    static let isShownKey = "OviIsShown"
    static let tipStateKey = "OviTipState"
    static let shownTodayKey = "OviShownToday"

    private struct Day: Codable {
        let day: String
        let count: Int
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// "Show Ovi" (Settings, and ⋯ → Turn off Ovi).
    var isShown: Bool {
        get { defaults.object(forKey: Self.isShownKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.isShownKey) }
    }

    func record(_ id: OviTipID) -> OviTipRecord? {
        records[id.rawValue]
    }

    func update(_ id: OviTipID, _ change: (inout OviTipRecord) -> Void) {
        var all = records
        var record = all[id.rawValue] ?? OviTipRecord()
        change(&record)
        all[id.rawValue] = record
        defaults.set(try? JSONEncoder().encode(all), forKey: Self.tipStateKey)
    }

    /// How many "!" appeared on the Mac's calendar day of `now`.
    func shownToday(now: Date) -> Int {
        guard let data = defaults.data(forKey: Self.shownTodayKey),
              let day = try? JSONDecoder().decode(Day.self, from: data),
              day.day == key(for: now)
        else { return 0 }
        return day.count
    }

    func countShown(now: Date) {
        let day = Day(day: key(for: now), count: shownToday(now: now) + 1)
        defaults.set(try? JSONEncoder().encode(day), forKey: Self.shownTodayKey)
    }

    /// Settings → Reset Ovi's tips. "Show Ovi" stays as it is.
    func reset() {
        defaults.removeObject(forKey: Self.tipStateKey)
        defaults.removeObject(forKey: Self.shownTodayKey)
    }

    private var records: [String: OviTipRecord] {
        guard let data = defaults.data(forKey: Self.tipStateKey),
              let all = try? JSONDecoder().decode([String: OviTipRecord].self, from: data)
        else { return [:] }
        return all.filter { OviTipID(rawValue: $0.key) != nil }
    }

    private func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
