import UIKit

extension Amount {
    func displayText(locale: Locale = .current) -> String {
        units.formatted(.number.locale(locale))
    }

    func accessibilityText(locale: Locale = .current) -> String {
        "\(units.formatted(.number.grouping(.never).locale(locale))) Coincoins"
    }
}

extension Address {
    /// "a3f9…7c21": o suficiente para conferir de olho, sem ocupar a linha inteira.
    var short: String {
        "\(hex.prefix(4))…\(hex.suffix(4))"
    }
}

extension UIFont {
    /// SF Rounded com dígitos de largura fixa, escalando com o Dynamic Type.
    static func roundedDigits(size: CGFloat, weight: Weight, relativeTo style: TextStyle) -> UIFont {
        let base = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }

    static func rounded(_ style: TextStyle, weight: Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }
}

extension String {
    /// "a3f901bc…" → "a3f9 01bc …": blocos de 4 facilitam conferir de olho.
    func groupedInFours() -> String {
        stride(from: 0, to: count, by: 4).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: 4, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }.joined(separator: " ")
    }
}

extension UIFont {
    static func monospaced(_ style: TextStyle) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .monospacedSystemFont(ofSize: size, weight: .regular))
    }
}
