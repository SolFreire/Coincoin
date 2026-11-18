//
//  SendViewControler.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Combine
import LocalAuthentication
import UIKit

final class SendViewController: UIViewController {

    private let viewModel: SendViewModel
    private let onSent: (TrackedTransaction) -> Void
    private var cancellables = Set<AnyCancellable>()

    private let amountField = UITextField()
    private let amountHint = UILabel()
    private let addressField = UITextField()
    private let addressHint = UILabel()
    private let failureLabel = UILabel()
    private let sendButton = UIButton(configuration: .prominentGlass())

    static func sheet(viewModel: SendViewModel, onSent: @escaping (TrackedTransaction) -> Void) -> UIViewController {
        let navigation = UINavigationController(rootViewController: SendViewController(viewModel: viewModel, onSent: onSent))
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    init(viewModel: SendViewModel, onSent: @escaping (TrackedTransaction) -> Void) {
        self.viewModel = viewModel
        self.onSent = onSent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Enviar")
        view.backgroundColor = .background
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        buildLayout()
        bind()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        amountField.becomeFirstResponder()
    }

    // MARK: - Layout

    private func buildLayout() {
        amountField.placeholder = "0"
        amountField.keyboardType = .numberPad
        amountField.textAlignment = .center
        amountField.font = .roundedDigits(size: 48, weight: .semibold, relativeTo: .largeTitle)
        amountField.adjustsFontForContentSizeCategory = true
        amountField.accessibilityLabel = String(localized: "Valor em Coincoins")
        amountField.addAction(UIAction { [weak self] _ in
            self?.viewModel.amountText = self?.amountField.text ?? ""
        }, for: .editingChanged)

        let currency = UILabel()
        currency.text = "CC"
        currency.font = .rounded(.title2, weight: .semibold)
        currency.textColor = .secondaryLabel
        currency.adjustsFontForContentSizeCategory = true
        currency.isAccessibilityElement = false

        let amountRow = UIStackView(arrangedSubviews: [amountField, currency])
        amountRow.spacing = 6
        amountRow.alignment = .firstBaseline

        configureHint(amountHint)
        amountHint.textAlignment = .center

        addressField.placeholder = String(localized: "Endereço de destino")
        addressField.font = .monospaced(.body)
        addressField.adjustsFontForContentSizeCategory = true
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.spellCheckingType = .no
        addressField.smartInsertDeleteType = .no
        addressField.textContentType = .none
        addressField.clearButtonMode = .whileEditing
        addressField.addAction(UIAction { [weak self] _ in
            self?.viewModel.addressText = self?.addressField.text ?? ""
        }, for: .editingChanged)

        var pasteConfiguration = UIButton.Configuration.plain()
        pasteConfiguration.image = UIImage(systemName: "doc.on.clipboard")
        pasteConfiguration.baseForegroundColor = .accent
        let pasteButton = UIButton(configuration: pasteConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.pasteAddress()
        })
        pasteButton.accessibilityLabel = String(localized: "Colar endereço")
        pasteButton.setContentHuggingPriority(.required, for: .horizontal)

        let addressRow = UIStackView(arrangedSubviews: [addressField, pasteButton])
        addressRow.spacing = 4
        addressRow.alignment = .center
        addressRow.isLayoutMarginsRelativeArrangement = true
        addressRow.directionalLayoutMargins = .init(top: 6, leading: 16, bottom: 6, trailing: 6)
        addressRow.backgroundColor = .surface
        addressRow.layer.cornerRadius = 16
        addressRow.layer.cornerCurve = .continuous

        configureHint(addressHint)

        configureHint(failureLabel)
        failureLabel.textAlignment = .center

        var buttonConfiguration = sendButton.configuration ?? .prominentGlass()
        buttonConfiguration.title = String(localized: "Enviar")
        buttonConfiguration.image = UIImage(systemName: Self.biometrySymbol)
        buttonConfiguration.imagePadding = 8
        buttonConfiguration.buttonSize = .large
        sendButton.configuration = buttonConfiguration
        sendButton.tintColor = .accent
        sendButton.addAction(UIAction { [weak self] _ in
            self?.send()
        }, for: .primaryActionTriggered)

        let amountSection = UIStackView(arrangedSubviews: [amountRow, amountHint])
        amountSection.axis = .vertical
        amountSection.alignment = .center
        amountSection.spacing = 8

        let addressSection = UIStackView(arrangedSubviews: [addressRow, addressHint])
        addressSection.axis = .vertical
        addressSection.spacing = 6

        let content = UIStackView(arrangedSubviews: [amountSection, addressSection, failureLabel])
        content.axis = .vertical
        content.spacing = 28
        content.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        view.addSubview(sendButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            addressRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            pasteButton.widthAnchor.constraint(equalToConstant: 44),
            pasteButton.heightAnchor.constraint(equalToConstant: 44),

            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sendButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
        ])
    }

    private func configureHint(_ label: UILabel) {
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    private static var biometrySymbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "touchid" : "faceid"
    }

    // MARK: - Ações

    private func pasteAddress() {
        guard let text = UIPasteboard.general.string else { return }
        addressField.text = text
        viewModel.addressText = text
    }

    private func send() {
        view.endEditing(true)
        Task { await viewModel.send() }
    }

    // MARK: - Estado

    private func bind() {
        viewModel.$amountIssue
            .combineLatest(viewModel.$addressIssue, viewModel.$status)
            .sink { [weak self] amountIssue, addressIssue, status in
                self?.render(amountIssue: amountIssue, addressIssue: addressIssue, status: status)
            }
            .store(in: &cancellables)
    }

    private func render(
        amountIssue: SendViewModel.AmountIssue?,
        addressIssue: SendViewModel.AddressIssue?,
        status: SendViewModel.Status
    ) {
        setHint(amountHint, issue: amountIssue?.message,
                fallback: String(localized: "Disponível: \(viewModel.available.displayText()) CC"))
        setHint(addressHint, issue: addressIssue?.message, fallback: nil)

        let isSending = status == .sending
        amountField.isEnabled = !isSending
        addressField.isEnabled = !isSending
        isModalInPresentation = isSending
        sendButton.configuration?.showsActivityIndicator = isSending
        sendButton.isEnabled = viewModel.canSend

        switch status {
        case .failed(let error):
            setHint(failureLabel, issue: error.userMessage, fallback: nil)
            UIAccessibility.post(notification: .announcement, argument: error.userMessage)
        case .sent(let transaction):
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSent(transaction)
            dismiss(animated: true)
        case .editing, .sending:
            setHint(failureLabel, issue: nil, fallback: nil)
        }
    }

    private func setHint(_ label: UILabel, issue: String?, fallback: String?) {
        guard let text = issue ?? fallback, !text.isEmpty else {
            label.attributedText = nil
            label.isHidden = true
            return
        }
        label.isHidden = false
        guard let issue, !issue.isEmpty else {
            label.attributedText = NSAttributedString(string: text)
            return
        }
        let icon = NSTextAttachment(image: UIImage(systemName: "exclamationmark.circle.fill")!
            .withTintColor(.systemRed, renderingMode: .alwaysOriginal))
        let result = NSMutableAttributedString(attachment: icon)
        result.append(NSAttributedString(string: " " + issue))
        label.attributedText = result
    }
}
