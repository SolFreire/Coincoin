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

        let content = UIStackView(arrangedSubviews: [nodeRow, balanceCard, recentTitle, recentList, emptyLabel])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(28, after: balanceCard)
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

    // MARK: - Estado

    private func bind() {
        viewModel.$snapshot
            .combineLatest(viewModel.$problem, viewModel.$isLoading)
            .sink { [weak self] snapshot, problem, isLoading in
                self?.render(snapshot: snapshot, problem: problem, isLoading: isLoading)
            }
            .store(in: &cancellables)
    }

    private func render(snapshot: WalletViewModel.Snapshot?, problem: WalletViewModel.Problem?, isLoading: Bool) {
        if !isLoading, refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }

        renderNodeStatus(snapshot: snapshot, problem: problem, isLoading: isLoading)
        balanceCard.show(amount: snapshot?.availableBalance)

        recentList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let recent = snapshot?.recent ?? []
        for transaction in recent {
            recentList.addArrangedSubview(TransactionRowView(transaction: transaction))
        }
        recentTitle.isHidden = snapshot == nil
        emptyLabel.isHidden = snapshot == nil || !recent.isEmpty
    }

    private func renderNodeStatus(snapshot: WalletViewModel.Snapshot?, problem: WalletViewModel.Problem?, isLoading: Bool) {
        let symbol: String
        let color: UIColor
        var text: String

        switch problem {
        case .unreachable?:
            (symbol, color, text) = ("wifi.exclamationmark", .systemOrange, String(localized: "Sem conexão com o nó"))
        case .syncing?:
            (symbol, color, text) = ("arrow.triangle.2.circlepath", .systemOrange, String(localized: "Nó sincronizando"))
        case .rejected?, .invalidResponse?:
            (symbol, color, text) = ("exclamationmark.triangle", .systemOrange, String(localized: "O nó respondeu com erro"))
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
