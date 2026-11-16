import UIKit

final class BalanceCardView: UIView {

    private let titleLabel = UILabel()
    private let amountLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .accent
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        titleLabel.text = String(localized: "Saldo disponível")
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .onAccent
        titleLabel.adjustsFontForContentSizeCategory = true

        amountLabel.textColor = .onAccent
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.5

        let stack = UIStackView(arrangedSubviews: [titleLabel, amountLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // O mascote espia pelo canto: sai um pouco da borda e o cartão corta o excesso.
        let mascot = UIImageView(image: UIImage(resource: .mascot))
        mascot.contentMode = .scaleAspectFit
        mascot.isAccessibilityElement = false
        mascot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mascot)
        clipsToBounds = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: mascot.leadingAnchor, constant: -8),

            mascot.widthAnchor.constraint(equalToConstant: 96),
            mascot.heightAnchor.constraint(equalTo: mascot.widthAnchor, multiplier: 44.0 / 64.0),
            mascot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
            mascot.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 8),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .header
        show(amount: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    func show(amount: Amount?) {
        let number = amount?.displayText() ?? "—"
        let text = NSMutableAttributedString(
            string: number,
            attributes: [.font: UIFont.roundedDigits(size: 38, weight: .semibold, relativeTo: .largeTitle)])
        text.append(NSAttributedString(
            string: " CC",
            attributes: [.font: UIFont.rounded(.title3, weight: .medium)]))
        amountLabel.attributedText = text

        accessibilityLabel = amount.map { "\(String(localized: "Saldo disponível")), \($0.accessibilityText())" }
            ?? String(localized: "Saldo disponível, carregando")
    }
}
