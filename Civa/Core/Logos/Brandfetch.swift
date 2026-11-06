//
//  Brandfetch.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Foundation

/// Brand search and logos from Brandfetch. Their terms require hotlinking logos and not caching
/// search results, so Civa keeps only the website the user picks (see `Organization`).
nonisolated enum Brandfetch {
    struct Brand: Decodable, Hashable, Identifiable {
        let brandId: String
        let name: String?
        let domain: String
        let icon: URL?

        var id: String { brandId }
        var title: String { name ?? domain }
    }

    /// The Settings switch for online logo lookups.
    static let fetchesLogosKey = "fetchesLogosOnline"

    /// From Config/Secrets.plist, which git ignores. Without it, logos fall back to initials.
    static let clientID: String? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let id = NSDictionary(contentsOf: url)?["BrandfetchClientID"] as? String,
              !id.isBlank
        else { return nil }
        return id
    }()

    /// Up to five brands matching `name`.
    static func search(_ name: String) async throws -> [Brand] {
        guard let clientID,
              let query = name.trimmingCharacters(in: .whitespaces).addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "https://api.brandfetch.io/v2/search/\(query)?c=\(clientID)&limit=5")
        else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Brand].self, from: data)
    }

    /// A square icon, or a 404 when Brandfetch has none so the initials stay.
    static func logoURL(domain: String) -> URL? {
        guard let clientID else { return nil }
        return URL(string: "https://cdn.brandfetch.io/\(domain)/w/128/h/128/fallback/404/icon.png?c=\(clientID)")
    }
}
