import UIKit

final class TransactionRowView: UIView {

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let amountLabel = UILabel()

    init(transaction: RecentTransaction) {
        super.init(frame: .zero)
        buildLayout()
        configure(with: transaction)
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

    private func configure(with transaction: RecentTransaction) {
        let amount = transaction.amount.displayText()
        let date = transaction.date.formatted(.relative(presentation: .named))
        subtitleLabel.text = date.prefix(1).uppercased() + date.dropFirst()

        switch transaction.direction {
        case .received:
            iconView.image = UIImage(systemName: "arrow.down.left")
            iconView.tintColor = .systemGreen
            iconBackground.backgroundColor = .systemGreen.withAlphaComponent(0.15)
            titleLabel.text = String(localized: "De \(transaction.counterparty.short)")
            amountLabel.text = "+\(amount)"
            amountLabel.textColor = .label
        case .sent:
            iconView.image = UIImage(systemName: "arrow.up.right")
            iconView.tintColor = .secondaryLabel
            iconBackground.backgroundColor = .tertiarySystemFill
            titleLabel.text = String(localized: "Para \(transaction.counterparty.short)")
            amountLabel.text = "−\(amount)"
            amountLabel.textColor = .label
        }

        isAccessibilityElement = true
        let verb = transaction.direction == .received ? String(localized: "Recebido") : String(localized: "Enviado")
        accessibilityLabel = "\(verb), \(transaction.amount.accessibilityText()), \(titleLabel.text ?? ""), \(date)"
    }
}
