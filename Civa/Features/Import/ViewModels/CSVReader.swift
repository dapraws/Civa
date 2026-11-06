//
//  CSVReader.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// Reads CSV (RFC 4180): quoted fields may hold commas, line breaks, and doubled quotes.
nonisolated enum CSVReader {
    /// Rows as dictionaries keyed by the header row.
    static func records(_ text: String) -> [[String: String]] {
        let rows = rows(text)
        guard let header = rows.first?.map({ $0.trimmingCharacters(in: .whitespaces) }) else { return [] }
        return rows.dropFirst().compactMap { row in
            guard row.contains(where: { !$0.isBlank }) else { return nil }
            var record: [String: String] = [:]
            for (index, key) in header.enumerated() where index < row.count {
                record[key] = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return record
        }
    }

    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.replacingOccurrences(of: "\u{FEFF}", with: "").makeIterator()
        var pending: Character?

        while let character = pending ?? iterator.next() {
            pending = nil
            if isQuoted {
                if character == "\"" {
                    let next = iterator.next()
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        isQuoted = false
                        pending = next
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty:
                isQuoted = true
            case ",":
                row.append(field)
                field = ""
            case "\n", "\r\n", "\r":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
