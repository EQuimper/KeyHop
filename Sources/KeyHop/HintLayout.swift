import Foundation

struct HintAnchor {
    let target: CGRect
    let size: CGSize
}

enum HintLayout {
    // Keep every unobstructed label in its original place before moving its neighbors.
    static func frames(for anchors: [HintAnchor], in bounds: CGRect, avoiding reserved: CGRect) -> [CGRect?] {
        var occupied = [reserved]
        var frames = [CGRect?](repeating: nil, count: anchors.count)

        func candidate(_ anchor: HintAnchor, column: Int = 0, row: Int = 0) -> CGRect {
            let size = anchor.size
            let x = anchor.target.minX + CGFloat(column) * (size.width + 4)
            let y = anchor.target.minY - 12 + CGFloat(row) * (size.height + 4)
            return CGRect(x: max(bounds.minX, min(x.rounded(), bounds.maxX - size.width)),
                          y: max(bounds.minY, min(y.rounded(), bounds.maxY - size.height)),
                          width: size.width, height: size.height)
        }

        func place(_ box: CGRect, at index: Int) -> Bool {
            guard bounds.contains(box), !occupied.contains(where: { $0.intersects(box) }) else { return false }
            frames[index] = box
            occupied.append(box.insetBy(dx: -3, dy: -3))
            return true
        }

        for (i, anchor) in anchors.enumerated() { _ = place(candidate(anchor), at: i) }
        for (i, anchor) in anchors.enumerated() where frames[i] == nil {
            guard anchor.size.width <= bounds.width, anchor.size.height <= bounds.height else { continue }
            let columns = Int(ceil(bounds.width / (anchor.size.width + 4)))
            let rows = Int(ceil(bounds.height / (anchor.size.height + 4)))
            search: for radius in 1...max(1, max(rows, columns)) {
                // Try lateral offsets first: dense vertical lists keep their row alignment.
                let nearRows = [0] + (1...radius).flatMap { [-$0, $0] }
                for row in nearRows where abs(row) <= rows && radius <= columns {
                    for column in [radius, -radius] {
                        if place(candidate(anchor, column: column, row: row), at: i) {
                            break search
                        }
                    }
                }
                for column in (-radius + 1)..<radius {
                    for row in [-radius, radius] where abs(column) <= columns && radius <= rows {
                        if place(candidate(anchor, column: column, row: row), at: i) { break search }
                    }
                }
            }
        }
        return frames
    }
}
