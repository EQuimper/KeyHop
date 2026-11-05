import Foundation

struct ClickHint {
    let label: String
    let members: [Int]

    static func make(rects: [CGRect], candidates: [Int], groupMarkers: Bool, letters: [Character] = Hints.alphabet, spatialBounds: CGRect? = nil) -> [ClickHint] {
        let groups = groupMarkers ? markerColumns(rects: rects, candidates: candidates) : []
        let members = Set(groups.flatMap { $0 })
        let singles = candidates.filter { !members.contains($0) }
        if let spatialBounds {
            let entries = singles.map { [$0] } + groups
            let points = entries.map { entry -> CGPoint in
                let rect = rects[entry[(entry.count - 1) / 2]]
                return CGPoint(x: rect.midX, y: rect.midY)
            }
            return zip(SpatialKeymap.labels(points: points, bounds: spatialBounds), entries)
                .map { ClickHint(label: $0, members: $1) }
        }
        // Give groups short keys, keeping those keys out of the ordinary label alphabet.
        let preferred = Array("ghrueiwop").filter(letters.contains)
        let available = preferred + letters.filter { !preferred.contains($0) }
        let groupKeys = available.prefix(min(groups.count, max(0, letters.count - 2)))
        let alphabet = letters.filter { !groupKeys.contains($0) }
        let labels = Hints.labels(count: singles.count + groups.count - groupKeys.count, alphabet: alphabet)
        let groupLabels = groupKeys.map(String.init) + Array(labels.dropFirst(singles.count))
        return zip(singles, labels).map { ClickHint(label: $1, members: [$0]) }
            + zip(groups, groupLabels).map { ClickHint(label: $1, members: $0) }
    }

    private static func markerColumns(rects: [CGRect], candidates: [Int]) -> [[Int]] {
        let small = candidates.filter { rects[$0].width <= 64 && rects[$0].height <= 18 }
            .sorted { rects[$0].minX < rects[$1].minX }
        var groups: [[Int]] = []
        var columnStart = 0
        while columnStart < small.count {
            let left = rects[small[columnStart]].minX
            var end = columnStart + 1
            while end < small.count && rects[small[end]].minX - left <= 4 { end += 1 }
            let column = small[columnStart..<end].sorted {
                let a = rects[$0].midY, b = rects[$1].midY
                return a == b ? $0 < $1 : a < b
            }
            var run: [Int] = []
            for index in column {
                if let last = run.last, rects[index].midY - rects[last].midY > 20 {
                    if run.count >= 3 { groups.append(run) }
                    run.removeAll(keepingCapacity: true)
                }
                run.append(index)
            }
            if run.count >= 3 { groups.append(run) }
            columnStart = end
        }
        return groups
    }
}
