//
//  ReceiveViewController.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import UIKit

final class ReceiveViewController: UIViewController {

    private let wallet: Address
    private let copyButton = UIButton(configuration: .glass())

    static func sheet(for wallet: Address) -> UIViewController {
        let navigation = UINavigationController(rootViewController: ReceiveViewController(wallet: wallet))
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    init(wallet: Address) {
        self.wallet = wallet
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Receber")
        view.backgroundColor = .background
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        buildLayout()
    }

    // MARK: - Layout

    private func buildLayout() {
        let qrSide: CGFloat = 220
        let qrView = UIImageView(image: QRCode.image(
            for: PaymentRequest(address: wallet).uri, side: qrSide, scale: traitCollection.displayScale))
        qrView.layer.magnificationFilter = .nearest
        qrView.isAccessibilityElement = true
        qrView.accessibilityLabel = String(localized: "QR code do seu endereço")
        qrView.translatesAutoresizingMaskIntoConstraints = false

        let qrCard = UIView()
        qrCard.backgroundColor = .white
        qrCard.layer.cornerRadius = 20
        qrCard.layer.cornerCurve = .continuous
        qrCard.addSubview(qrView)
        NSLayoutConstraint.activate([
            qrView.widthAnchor.constraint(equalToConstant: qrSide),
            qrView.heightAnchor.constraint(equalToConstant: qrSide),
            qrView.topAnchor.constraint(equalTo: qrCard.topAnchor, constant: 16),
            qrView.bottomAnchor.constraint(equalTo: qrCard.bottomAnchor, constant: -16),
            qrView.leadingAnchor.constraint(equalTo: qrCard.leadingAnchor, constant: 16),
            qrView.trailingAnchor.constraint(equalTo: qrCard.trailingAnchor, constant: -16),
        ])
        let qrRow = UIStackView(arrangedSubviews: [qrCard])
        qrRow.axis = .vertical
        qrRow.alignment = .center

        let caption = UILabel()
        caption.text = String(localized: "Seu endereço Coincoin")
        caption.font = .preferredFont(forTextStyle: .subheadline)
        caption.textColor = .secondaryLabel
        caption.textAlignment = .center
        caption.adjustsFontForContentSizeCategory = true

        let addressLabel = UILabel()
        addressLabel.text = wallet.hex.groupedInFours()
        addressLabel.font = .monospaced(.title3)
        addressLabel.textAlignment = .center
        addressLabel.numberOfLines = 0
        addressLabel.adjustsFontForContentSizeCategory = true
        addressLabel.accessibilityLabel = String(localized: "Endereço \(wallet.hex)")

        let addressCard = UIStackView(arrangedSubviews: [addressLabel])
        addressCard.isLayoutMarginsRelativeArrangement = true
        addressCard.directionalLayoutMargins = .init(top: 16, leading: 20, bottom: 16, trailing: 20)
        addressCard.backgroundColor = .surface
        addressCard.layer.cornerRadius = 16
        addressCard.layer.cornerCurve = .continuous

        let note = UILabel()
        note.text = String(localized: "Envie este endereço para quem vai te pagar. Ele só recebe Coincoin.")
        note.font = .preferredFont(forTextStyle: .footnote)
        note.textColor = .secondaryLabel
        note.textAlignment = .center
        note.numberOfLines = 0
        note.adjustsFontForContentSizeCategory = true

        var copyConfiguration = copyButton.configuration ?? .glass()
        copyConfiguration.title = String(localized: "Copiar")
        copyConfiguration.image = UIImage(systemName: "doc.on.doc")
        copyConfiguration.imagePadding = 6
        copyConfiguration.buttonSize = .large
        copyButton.configuration = copyConfiguration
        copyButton.tintColor = .accent
        copyButton.addAction(UIAction { [weak self] _ in
            self?.copyAddress()
        }, for: .primaryActionTriggered)

        var shareConfiguration = UIButton.Configuration.prominentGlass()
        shareConfiguration.title = String(localized: "Compartilhar")
        shareConfiguration.image = UIImage(systemName: "square.and.arrow.up")
        shareConfiguration.imagePadding = 6
        shareConfiguration.buttonSize = .large
        let shareButton = UIButton(configuration: shareConfiguration, primaryAction: UIAction { [weak self] action in
            self?.shareAddress(from: action.sender as? UIView)
        })
        shareButton.tintColor = .accent

        let buttons = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let content = UIStackView(arrangedSubviews: [qrRow, caption, addressCard, note, buttons])
        content.axis = .vertical
        content.spacing = 16
        content.setCustomSpacing(24, after: qrRow)
        content.setCustomSpacing(8, after: caption)
        content.setCustomSpacing(28, after: note)
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
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Ações

    private func copyAddress() {
        UIPasteboard.general.string = wallet.hex
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Endereço copiado"))
        copyButton.configuration?.title = String(localized: "Copiado")
        copyButton.configuration?.image = UIImage(systemName: "checkmark")
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.copyButton.configuration?.title = String(localized: "Copiar")
            self?.copyButton.configuration?.image = UIImage(systemName: "doc.on.doc")
        }
    }

    private func shareAddress(from source: UIView?) {
        let activity = UIActivityViewController(activityItems: [wallet.hex], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = source
        present(activity, animated: true)
    }
}
