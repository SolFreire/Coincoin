//
//  OnboardingViewController.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 19/11/26.
//
import Combine
import UIKit

final class OnboardingViewController: UIViewController {

    private let viewModel: OnboardingViewModel
    private let makeNext: (any TransactionSigner) -> UIViewController
    private var cancellables = Set<AnyCancellable>()
    private let failureLabel = UILabel()

    init(viewModel: OnboardingViewModel, makeNext: @escaping (any TransactionSigner) -> UIViewController) {
        self.viewModel = viewModel
        self.makeNext = makeNext
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        buildLayout()
        viewModel.$failed
            .sink { [weak self] failed in
                self?.failureLabel.isHidden = !failed
            }
            .store(in: &cancellables)
    }

    // MARK: - Textos

    private var texts: (title: String, body: String, points: [(symbol: String, text: String)], action: String) {
        switch viewModel.mode {
        case .create:
            (String(localized: "Sua carteira Coincoin"),
             String(localized: "A chave da carteira é criada e guardada no chip de segurança deste iPhone. Ela nunca sai dele."),
             [("faceid", String(localized: "Cada transferência pede Face ID ou o código do aparelho.")),
              ("iphone", String(localized: "A carteira existe só neste iPhone. Não há backup: se ele for apagado ou trocado, o saldo dela se perde."))],
             String(localized: "Criar carteira"))
        case .demoOnly:
            (String(localized: "Carteira de demonstração"),
             String(localized: "Este aparelho não consegue guardar a chave no chip de segurança (simulador ou iPhone sem código)."),
             [("exclamationmark.triangle", String(localized: "Dá para testar o app, mas a carteira não fica salva: ao fechar o app, ela é perdida."))],
             String(localized: "Usar demonstração"))
        case .unavailable:
            (String(localized: "Carteira inacessível"),
             String(localized: "A carteira deste aparelho não pode mais ser aberta. Isso acontece quando o iPhone é restaurado de um backup ou o código do aparelho é removido."),
             [("xmark.shield", String(localized: "O saldo dessa carteira não pode ser recuperado.")),
              ("plus.circle", String(localized: "Você pode criar uma carteira nova, com outro endereço."))],
             String(localized: "Criar carteira nova"))
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        let texts = texts

        let mascot = UIImageView(image: UIImage(resource: .mascot))
        mascot.contentMode = .scaleAspectFit
        mascot.isAccessibilityElement = false
        mascot.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let title = UILabel()
        title.text = texts.title
        title.font = .rounded(.largeTitle, weight: .bold)
        title.textAlignment = .center
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header

        let body = UILabel()
        body.text = texts.body
        body.font = .preferredFont(forTextStyle: .body)
        body.textColor = .secondaryLabel
        body.textAlignment = .center
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true

        let points = UIStackView(arrangedSubviews: texts.points.map(makePoint))
        points.axis = .vertical
        points.spacing = 16
        points.isLayoutMarginsRelativeArrangement = true
        points.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        points.backgroundColor = .surface
        points.layer.cornerRadius = 16
        points.layer.cornerCurve = .continuous

        failureLabel.text = String(localized: "Não foi possível criar a carteira. Tente de novo.")
        failureLabel.font = .preferredFont(forTextStyle: .footnote)
        failureLabel.textColor = .secondaryLabel
        failureLabel.textAlignment = .center
        failureLabel.numberOfLines = 0
        failureLabel.adjustsFontForContentSizeCategory = true
        failureLabel.isHidden = true

        let content = UIStackView(arrangedSubviews: [mascot, title, body, points, failureLabel])
        content.axis = .vertical
        content.spacing = 16
        content.setCustomSpacing(24, after: mascot)
        content.setCustomSpacing(28, after: body)
        content.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        var configuration = UIButton.Configuration.prominentGlass()
        configuration.title = texts.action
        configuration.buttonSize = .large
        let actionButton = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.confirmAndStart()
        })
        actionButton.tintColor = viewModel.mode == .unavailable ? .systemRed : .accent
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 48),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),

            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func makePoint(_ point: (symbol: String, text: String)) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: point.symbol))
        icon.tintColor = .accent
        icon.preferredSymbolConfiguration = .init(textStyle: .title3)
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let label = UILabel()
        label.text = point.text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 12
        row.alignment = .top
        return row
    }

    // MARK: - Ações

    private func confirmAndStart() {
        guard viewModel.mode == .unavailable else {
            start()
            return
        }
        let alert = UIAlertController(
            title: String(localized: "Apagar a carteira antiga?"),
            message: String(localized: "A carteira que não abre será apagada deste aparelho e uma nova será criada. Isso não pode ser desfeito."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Cancelar"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Apagar e criar"), style: .destructive) { [weak self] _ in
            self?.start()
        })
        present(alert, animated: true)
    }

    private func start() {
        guard let signer = viewModel.start(), let window = view.window else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        window.rootViewController = makeNext(signer)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
}
