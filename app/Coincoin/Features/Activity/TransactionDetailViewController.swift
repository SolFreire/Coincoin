import UIKit

final class TransactionDetailViewController: UIViewController {

    private let transaction: TransactionSummary

    static func sheet(for transaction: TransactionSummary) -> UIViewController {
        let navigation = UINavigationController(rootViewController: TransactionDetailViewController(transaction: transaction))
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    init(transaction: TransactionSummary) {
        self.transaction = transaction
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        let header = UIStackView(arrangedSubviews: [makeStatusPill(), makeAmountLabel(), makeDateLabel()])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 8

        let content = UIStackView(arrangedSubviews: [header, makeTimeline(), makeFieldsCard()])
        content.axis = .vertical
        content.spacing = 24
        content.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Cabeçalho

    private func makeStatusPill() -> UIView {
        let (symbol, tint): (String, UIColor) = switch transaction.state {
        case .pending: ("clock", .systemOrange)
        case .confirmed: ("checkmark.circle", .systemGreen)
        case .failed: ("xmark.circle", .systemRed)
        }
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = tint
        icon.preferredSymbolConfiguration = .init(textStyle: .footnote)
        let label = UILabel()
        label.text = transaction.statusText
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true

        let pill = UIStackView(arrangedSubviews: [icon, label])
        pill.spacing = 4
        pill.isLayoutMarginsRelativeArrangement = true
        pill.directionalLayoutMargins = .init(top: 4, leading: 10, bottom: 4, trailing: 10)
        pill.backgroundColor = tint.withAlphaComponent(0.15)
        pill.layer.cornerRadius = 12
        pill.layer.cornerCurve = .continuous
        return pill
    }

    private func makeAmountLabel() -> UILabel {
        let label = UILabel()
        label.text = "\(transaction.signedAmountText) CC"
        label.font = .roundedDigits(size: 34, weight: .semibold, relativeTo: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityLabel = transaction.amount.accessibilityText()
        return label
    }

    private func makeDateLabel() -> UILabel {
        let label = UILabel()
        label.text = transaction.date.formatted(date: .long, time: .shortened)
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    // MARK: - Linha do tempo

    private enum StepState {
        case done, waiting, failed
    }

    private func makeTimeline() -> UIView {
        let last: (StepState, String) = switch transaction.state {
        case .confirmed: (.done, String(localized: "Em bloco"))
        case .pending: (.waiting, String(localized: "Em bloco"))
        case .failed: (.failed, String(localized: "Recusada no bloco"))
        }
        let steps: [(StepState, String)] = [
            (.done, String(localized: "Assinada")),
            (transaction.isUncertain ? .waiting : .done, String(localized: "Aceita pelo nó")),
            last,
        ]

        let row = UIStackView(arrangedSubviews: steps.map(makeStep))
        row.distribution = .fillEqually
        row.isAccessibilityElement = true
        row.accessibilityLabel = steps.map { state, title in
            switch state {
            case .done: String(localized: "\(title): concluído")
            case .waiting: String(localized: "\(title): aguardando")
            case .failed: title
            }
        }.joined(separator: ", ")
        return row
    }

    private func makeStep(_ step: (state: StepState, title: String)) -> UIView {
        let (symbol, tint): (String, UIColor) = switch step.state {
        case .done: ("checkmark.circle.fill", .systemGreen)
        case .waiting: ("circle.dashed", .tertiaryLabel)
        case .failed: ("xmark.circle.fill", .systemRed)
        }
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = tint
        icon.preferredSymbolConfiguration = .init(textStyle: .title3)
        let label = UILabel()
        label.text = step.title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = step.state == .waiting ? .secondaryLabel : .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }

    // MARK: - Campos

    private func makeFieldsCard() -> UIView {
        var fields: [UIView] = [
            makeField(
                title: transaction.direction == .received ? String(localized: "De") : String(localized: "Para"),
                value: transaction.counterparty.hex.groupedInFours(),
                copyValue: transaction.counterparty.hex,
                monospaced: true),
            makeField(
                title: String(localized: "Hash"),
                value: transaction.id.hex.groupedInFours(),
                copyValue: transaction.id.hex,
                monospaced: true),
            makeField(title: String(localized: "Nonce"), value: transaction.nonce.formatted()),
            makeField(
                title: String(localized: "Bloco"),
                value: transaction.height.map { $0.formatted() } ?? "—"),
        ]
        if case .failed(let code) = transaction.state {
            fields.append(makeField(title: String(localized: "Motivo"), value: code.rawValue, monospaced: true))
        }

        let list = UIStackView()
        list.axis = .vertical
        for (index, field) in fields.enumerated() {
            if index > 0 { list.addArrangedSubview(makeDivider()) }
            list.addArrangedSubview(field)
        }
        list.isLayoutMarginsRelativeArrangement = true
        list.directionalLayoutMargins = .init(top: 4, leading: 16, bottom: 4, trailing: 8)
        list.backgroundColor = .surface
        list.layer.cornerRadius = 16
        list.layer.cornerCurve = .continuous
        return list
    }

    private func makeField(title: String, value: String, copyValue: String? = nil, monospaced: Bool = false) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = monospaced ? .monospaced(.subheadline) : .preferredFont(forTextStyle: .body)
        valueLabel.numberOfLines = 0
        valueLabel.adjustsFontForContentSizeCategory = true

        let texts = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        texts.axis = .vertical
        texts.spacing = 2
        texts.isAccessibilityElement = true
        texts.accessibilityLabel = "\(title), \(copyValue ?? value)"

        let row = UIStackView(arrangedSubviews: [texts])
        row.alignment = .center
        row.spacing = 8
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = .init(top: 10, leading: 0, bottom: 10, trailing: copyValue == nil ? 8 : 0)
        if let copyValue {
            row.addArrangedSubview(makeCopyButton(copying: copyValue, label: title))
        }
        return row
    }

    private func makeCopyButton(copying value: String, label: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "doc.on.doc")
        configuration.baseForegroundColor = .accent
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = String(localized: "Copiar \(label)")
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.addAction(UIAction { [weak button] _ in
            UIPasteboard.general.string = value
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Copiado"))
            button?.configuration?.image = UIImage(systemName: "checkmark")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                button?.configuration?.image = UIImage(systemName: "doc.on.doc")
            }
        }, for: .primaryActionTriggered)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        return button
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .divider
        divider.heightAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1)).isActive = true
        return divider
    }
}
