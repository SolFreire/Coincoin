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
