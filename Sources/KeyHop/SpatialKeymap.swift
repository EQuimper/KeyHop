import Foundation

enum SpatialKeymap {
    static let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

    static func labels(points: [CGPoint], bounds: CGRect) -> [String] {
        guard bounds.width > 0, bounds.height > 0 else { return Hints.labels(count: points.count) }
        func cell(_ p: CGPoint) -> Character {
            let y = min(0.999999, max(0, (p.y - bounds.minY) / bounds.height))
            let row = Array(rows[Int(y * 3)])
            let x = min(0.999999, max(0, (p.x - bounds.minX) / bounds.width))
            return row[Int(x * CGFloat(row.count))]
        }
        let buckets = Dictionary(grouping: points.indices, by: { cell(points[$0]) })
        var result = Array(repeating: "", count: points.count)
        let alphabet = Array(rows.joined())
        for (key, bucket) in buckets {
            if bucket.count == 1 { result[bucket[0]] = String(key); continue }
            let sorted = bucket.sorted { a, b in
                if points[a].y != points[b].y { return points[a].y < points[b].y }
                if points[a].x != points[b].x { return points[a].x < points[b].x }
                return a < b
            }
            for (index, suffix) in zip(sorted, Hints.labels(count: sorted.count, alphabet: alphabet)) {
                result[index] = String(key) + suffix
            }
        }
        return result
    }
}
