//
//  URLHistory.swift
//  Browsify
//
//  Tracks recently opened URLs for review.
//

import Foundation

struct URLHistoryEntry: Identifiable, Codable {
    let id: UUID
    let url: String
    let browserName: String
    let date: Date
    let ruleMatched: Bool

    init(url: String, browserName: String, ruleMatched: Bool) {
        self.id = UUID()
        self.url = url
        self.browserName = browserName
        self.date = Date()
        self.ruleMatched = ruleMatched
    }
}

class URLHistory: ObservableObject {
    static let shared = URLHistory()

    @Published private(set) var entries: [URLHistoryEntry] = []

    private let key = "urlHistory"
    private let maxEntries = 50

    private init() {
        load()
    }

    func add(url: String, browserName: String, ruleMatched: Bool) {
        let entry = URLHistoryEntry(url: url, browserName: browserName, ruleMatched: ruleMatched)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([URLHistoryEntry].self, from: data) else { return }
        entries = decoded
    }
}
