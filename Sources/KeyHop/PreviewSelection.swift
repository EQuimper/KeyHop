import Foundation

struct PreviewSelection {
    static let lines = [["Keep", "both", "hands"], ["on", "the", "keyboard"], ["as", "you", "select."]]
    static let words = lines.flatMap { $0 }
    var query = ""
    var anchor: Int?
    var cursor = 0
    var finished = false
    var candidates: [Int] {
        Self.words.indices.filter { query.isEmpty || Self.words[$0].localizedCaseInsensitiveContains(query) }
    }
    var current: Int? { candidates.indices.contains(cursor) ? candidates[cursor] : nil }
    var range: ClosedRange<Int>? {
        guard let current else { return nil }
        let start = anchor ?? current
        return min(start, current)...max(start, current)
    }
    mutating func edit(_ value: String) {
        if finished { self = Self() }
        query = value
        cursor = 0
    }
    mutating func step(_ delta: Int) {
        let count = candidates.count
        if count > 0 { cursor = (cursor + count + delta) % count }
    }
    mutating func choose(_ index: Int) {
        guard let position = candidates.firstIndex(of: index), !finished else { return }
        if anchor == nil {
            anchor = index
            query = ""
            cursor = index
        } else {
            cursor = position
            finished = true
        }
    }
}
