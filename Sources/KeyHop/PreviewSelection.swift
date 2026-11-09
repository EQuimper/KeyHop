import Foundation

struct PreviewSelection {
    static let lines = [["Keep", "both", "hands"], ["on", "the", "keyboard"], ["as", "you", "select."]]
    static let words = lines.flatMap { $0 }
    var query = ""
    var anchor: Int?
    private(set) var current: Int? = 0
    var finished = false
    var candidates: [Int] {
        Self.words.indices.filter { query.isEmpty || Self.words[$0].localizedCaseInsensitiveContains(query) }
    }
    var range: ClosedRange<Int>? {
        guard let current else { return nil }
        let start = anchor ?? current
        return min(start, current)...max(start, current)
    }
    mutating func edit(_ value: String) {
        if finished { self = Self() }
        query = value
        current = SearchMatch.preferred(in: candidates, anchor: anchor, query: query)
    }
    mutating func step(_ delta: Int) {
        current = SearchMatch.step(in: candidates, from: current, by: delta)
    }
    mutating func choose(_ index: Int) {
        guard candidates.contains(index), !finished else { return }
        if anchor == nil {
            anchor = index
            query = ""
            current = index
        } else {
            current = index
            finished = true
        }
    }
}
