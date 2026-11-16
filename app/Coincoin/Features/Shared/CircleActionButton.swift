import UIKit

/// Botão circular de 56 pt com rótulo embaixo (design system: "Botão circular").
final class CircleActionButton: UIView {

    private let button = UIButton(configuration: .filled())
    private let titleLabel = UILabel()

    init(title: String, symbol: String, action: @escaping () -> Void) {
        super.init(frame: .zero)

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .accentSoft
        configuration.baseForegroundColor = .onAccentSoft
        configuration.image = UIImage(systemName: symbol)
        configuration.preferredSymbolConfigurationForImage = .init(pointSize: 22, weight: .medium)
        button.configuration = configuration
        button.accessibilityLabel = title
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        button.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.textColor = .onAccentSoft
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.isAccessibilityElement = false

        let stack = UIStackView(arrangedSubviews: [button, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }
}
