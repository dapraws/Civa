//
//  ClaudePermissions.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation
import Observation

/// Read and Suggest switches per category (FR-071). Everything starts off; choices last until the
/// user changes them.
@Observable
final class ClaudePermissions {
    static let shared = ClaudePermissions()
    private static let readKey = "ClaudeReadCategories"
    private static let suggestKey = "ClaudeSuggestCategories"

    var read: Set<ClaudeCategory> { didSet { save(read, Self.readKey) } }
    var suggest: Set<ClaudeCategory> { didSet { save(suggest, Self.suggestKey) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        read = Self.load(Self.readKey, from: defaults)
        suggest = Self.load(Self.suggestKey, from: defaults)
    }

    func canRead(_ category: ClaudeCategory) -> Bool { read.contains(category) }
    func canSuggest(_ category: ClaudeCategory) -> Bool { suggest.contains(category) }

    private static func load(_ key: String, from defaults: UserDefaults) -> Set<ClaudeCategory> {
        Set((defaults.stringArray(forKey: key) ?? []).compactMap(ClaudeCategory.init(rawValue:)))
    }

    private func save(_ value: Set<ClaudeCategory>, _ key: String) {
        defaults.set(value.map(\.rawValue).sorted(), forKey: key)
    }
}
