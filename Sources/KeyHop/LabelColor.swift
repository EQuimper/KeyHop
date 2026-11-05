import AppKit

enum LabelColor {
    static let original = NSColor(srgbRed: 1, green: 0.91, blue: 0.22, alpha: 1)
    private static let key = "labelColorRGB"

    static func load(from defaults: UserDefaults = .standard) -> NSColor {
        guard let rgb = defaults.array(forKey: key) as? [Double], rgb.count == 3,
              rgb.allSatisfy({ (0...1).contains($0) }) else { return original }
        return NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1)
    }

    static func save(_ color: NSColor, to defaults: UserDefaults = .standard) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        defaults.set([rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Double(min(1, max(0, $0))) },
                     forKey: key)
    }

    static func ink(on color: NSColor) -> NSColor {
        let rgb = color.usingColorSpace(.sRGB) ?? original
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? .black : .white
    }
}
