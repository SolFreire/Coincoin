import Combine
import UIKit

final class WalletViewController: UIViewController {

    private let viewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()
    private let refreshControl = UIRefreshControl()
    private let nodeIcon = UIImageView()
    private let nodeLabel = UILabel()
    private let balanceCard = BalanceCardView()
    private let recentTitle = UILabel()
    private let recentList = UIStackView()
    private let emptyLabel = UILabel()
    private var rowTransactions: [ObjectIdentifier: TransactionSummary] = [:]

    init(viewModel: WalletViewModel) {
        self.viewModel = viewModel
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
        bind()
        Task { await viewModel.load() }
    }

    // MARK: - Layout

    private func buildLayout() {
        nodeIcon.preferredSymbolConfiguration = .init(textStyle: .footnote)
        nodeIcon.setContentHuggingPriority(.required, for: .horizontal)
        nodeLabel.font = .preferredFont(forTextStyle: .footnote)
        nodeLabel.adjustsFontForContentSizeCategory = true
        nodeLabel.numberOfLines = 0
        let nodeRow = UIStackView(arrangedSubviews: [nodeIcon, nodeLabel])
        nodeRow.spacing = 6
        nodeRow.alignment = .center
        nodeRow.isAccessibilityElement = true

        recentTitle.text = String(localized: "Recentes")
        recentTitle.font = .preferredFont(forTextStyle: .headline)
        recentTitle.adjustsFontForContentSizeCategory = true
        recentTitle.accessibilityTraits = .header

        recentList.axis = .vertical

        emptyLabel.text = String(localized: "Quando você receber CC, as transações aparecem aqui.")
        emptyLabel.font = .preferredFont(forTextStyle: .subheadline)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.adjustsFontForContentSizeCategory = true

        let actions = UIStackView(arrangedSubviews: [
            CircleActionButton(title: String(localized: "Enviar"), symbol: "arrow.up") { [weak self] in
                self?.presentSend()
            },
            CircleActionButton(title: String(localized: "Receber"), symbol: "arrow.down") { [weak self] in
                self?.showComingSoon(String(localized: "Receber"))
            },
        ])
        actions.distribution = .fillEqually

        let content = UIStackView(arrangedSubviews: [nodeRow, balanceCard, actions, recentTitle, recentList, emptyLabel])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(20, after: balanceCard)
        content.setCustomSpacing(28, after: actions)
        content.setCustomSpacing(4, after: recentTitle)
        content.translatesAutoresizingMaskIntoConstraints = false

        scrollView.alwaysBounceVertical = true
        scrollView.refreshControl = refreshControl
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        view.addSubview(scrollView)

        refreshControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task { await self.viewModel.load() }
        }, for: .valueChanged)

        let margin: CGFloat = 20
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: margin),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -margin),
        ])
    }

    private func presentSend() {
        let sheet = SendViewController.sheet(viewModel: viewModel.makeSendViewModel()) { [weak self] _ in
            guard let self else { return }
            Task { await self.viewModel.load() }
        }
        present(sheet, animated: true)
    }

    // TODO(passo 8): abrir a sheet Receber.
    private func showComingSoon(_ feature: String) {
        let alert = UIAlertController(
            title: feature,
            message: String(localized: "Disponível em breve."),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        present(alert, animated: true)
    }

    // MARK: - Estado

    private func bind() {
        viewModel.$snapshot
            .combineLatest(viewModel.$problem, viewModel.$isLoading)
            .sink { [weak self] snapshot, problem, isLoading in
                self?.render(snapshot: snapshot, problem: problem, isLoading: isLoading)
            }
            .store(in: &cancellables)
    }

    private func render(snapshot: WalletViewModel.Snapshot?, problem: NodeProblem?, isLoading: Bool) {
        if !isLoading, refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }

        renderNodeStatus(snapshot: snapshot, problem: problem, isLoading: isLoading)
        balanceCard.show(amount: snapshot?.availableBalance)

        recentList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowTransactions.removeAll()
        let recent = snapshot?.recent ?? []
        for transaction in recent {
            let row = TransactionRowView(transaction: transaction)
            row.accessibilityTraits = .button
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(recentRowTapped(_:))))
            rowTransactions[ObjectIdentifier(row)] = transaction
            recentList.addArrangedSubview(row)
        }
        recentTitle.isHidden = snapshot == nil
        emptyLabel.isHidden = snapshot == nil || !recent.isEmpty
    }

    @objc private func recentRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view, let transaction = rowTransactions[ObjectIdentifier(row)] else { return }
        present(TransactionDetailViewController.sheet(for: transaction), animated: true)
    }

    private func renderNodeStatus(snapshot: WalletViewModel.Snapshot?, problem: NodeProblem?, isLoading: Bool) {
        let symbol: String
        let color: UIColor
        var text: String

        switch problem {
        case let problem?:
            (symbol, color, text) = (problem.symbol, .systemOrange, problem.message)
        case nil:
            if let snapshot {
                let height = snapshot.height.formatted()
                (symbol, color, text) = ("checkmark.circle", .systemGreen, String(localized: "nó \(snapshot.nodeId) · bloco \(height)"))
            } else {
                (symbol, color, text) = ("circle.dotted", .secondaryLabel, String(localized: "Conectando ao nó…"))
            }
        }

        if problem != nil, let snapshot {
            let time = snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)
            text += " · " + String(localized: "dados de \(time)")
        }

        nodeIcon.image = UIImage(systemName: symbol)
        nodeIcon.tintColor = color
        nodeLabel.textColor = .secondaryLabel
        nodeLabel.text = text
        nodeLabel.superview?.accessibilityLabel = text
    }
}
