import UIKit

final class TransactionRowView: UIView {

    enum Subtitle {
        case relativeDate
        case block
    }

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let amountLabel = UILabel()

    init() {
        super.init(frame: .zero)
        buildLayout()
    }

    convenience init(transaction: TransactionSummary, subtitle: Subtitle = .relativeDate) {
        self.init()
        configure(with: transaction, subtitle: subtitle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    private func buildLayout() {
        iconBackground.layer.cornerRadius = 16
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = .init(textStyle: .subheadline, scale: .medium)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(iconView)

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        amountLabel.font = .roundedDigits(size: 17, weight: .medium, relativeTo: .body)
        amountLabel.textColor = .label
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)

        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        texts.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconBackground, texts, amountLabel])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 32),
            iconBackground.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    func configure(with transaction: TransactionSummary, subtitle: Subtitle) {
        let look = transaction.appearance
        iconView.image = UIImage(systemName: look.symbol)
        iconView.tintColor = look.tint
        iconBackground.backgroundColor = look.background
        titleLabel.text = transaction.counterpartyText
        amountLabel.text = transaction.signedAmountText

        switch subtitle {
        case .relativeDate:
            subtitleLabel.text = transaction.relativeDateText
        case .block:
            subtitleLabel.text = transaction.height.map { String(localized: "Bloco \($0.formatted())") }
                ?? transaction.statusText
        }

        isAccessibilityElement = true
        accessibilityLabel = [
            transaction.direction == .received ? String(localized: "Recebido") : String(localized: "Enviado"),
            transaction.amount.accessibilityText(),
            transaction.counterpartyText,
            subtitleLabel.text ?? "",
        ].joined(separator: ", ")
    }
}

// MARK: - Aparência compartilhada (linha e detalhe)

extension TransactionSummary {
    struct Appearance {
        let symbol: String
        let tint: UIColor
        let background: UIColor
    }

    var appearance: Appearance {
        switch (state, direction) {
        case (.pending, _):
            Appearance(symbol: "clock", tint: .systemOrange, background: .systemOrange.withAlphaComponent(0.15))
        case (.failed, _):
            Appearance(symbol: "xmark", tint: .systemRed, background: .systemRed.withAlphaComponent(0.15))
        case (.confirmed, .received):
            Appearance(symbol: "arrow.down.left", tint: .systemGreen, background: .systemGreen.withAlphaComponent(0.15))
        case (.confirmed, .sent):
            Appearance(symbol: "arrow.up.right", tint: .secondaryLabel, background: .tertiarySystemFill)
        }
    }

    var counterpartyText: String {
        direction == .received
            ? String(localized: "De \(counterparty.short)")
            : String(localized: "Para \(counterparty.short)")
    }

    var signedAmountText: String {
        (direction == .received ? "+" : "−") + amount.displayText()
    }

    var relativeDateText: String {
        let text = date.formatted(.relative(presentation: .named))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    var statusText: String {
        switch state {
        case .pending: String(localized: "Pendente")
        case .confirmed: String(localized: "Confirmada")
        case .failed: String(localized: "Falhou")
        }
    }
}
