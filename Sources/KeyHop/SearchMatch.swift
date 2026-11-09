enum SearchMatch {
    static func preferred(in matches: [Int], anchor: Int?, query: String) -> Int? {
        guard let anchor else { return matches.first }
        if !query.isEmpty, let next = matches.first(where: { $0 > anchor }) { return next }
        return matches.contains(anchor) ? anchor : nil
    }

    static func step(in matches: [Int], from current: Int?, by delta: Int) -> Int? {
        guard let current, let position = matches.firstIndex(of: current) else {
            return delta < 0 ? matches.last : matches.first
        }
        return matches[(position + matches.count + delta) % matches.count]
    }
}
