import Combine
import UIKit

final class ActivityViewController: UIViewController, UITableViewDelegate {

    private typealias DataSource = ActivityDataSource
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Date, TransactionSummary>

    private let viewModel: ActivityViewModel
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private let footerSpinner = UIActivityIndicatorView(style: .medium)
    private lazy var dataSource = makeDataSource()

    init(viewModel: ActivityViewModel) {
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

        tableView.backgroundColor = .background
        tableView.delegate = self
        tableView.register(TransactionCell.self, forCellReuseIdentifier: TransactionCell.reuseID)
        tableView.refreshControl = refreshControl
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        refreshControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task { await self.viewModel.refresh() }
        }, for: .valueChanged)

        footerSpinner.frame.size.height = 56

        bind()
        Task { await viewModel.refresh() }
    }

    // MARK: - Estado

    private func bind() {
        viewModel.$sections
            .combineLatest(viewModel.$problem, viewModel.$isLoading, viewModel.$hasLoaded)
            .combineLatest(viewModel.$hasMore)
            .sink { [weak self] values, hasMore in
                let (sections, problem, isLoading, hasLoaded) = values
                self?.render(sections: sections, problem: problem, isLoading: isLoading, hasLoaded: hasLoaded, hasMore: hasMore)
            }
            .store(in: &cancellables)
    }

    private func render(
        sections: [ActivityViewModel.DaySection],
        problem: NodeProblem?,
        isLoading: Bool,
        hasLoaded: Bool,
        hasMore: Bool
    ) {
        if !isLoading, refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }

        var snapshot = Snapshot()
        for section in sections {
            snapshot.appendSections([section.day])
            snapshot.appendItems(section.items, toSection: section.day)
        }
        dataSource.apply(snapshot, animatingDifferences: hasLoaded)

        tableView.tableHeaderView = problem.map(makeProblemBanner)
        tableView.backgroundView = hasLoaded && sections.isEmpty ? makeEmptyState() : nil

        if hasMore {
            footerSpinner.startAnimating()
            tableView.tableFooterView = footerSpinner
        } else {
            footerSpinner.stopAnimating()
            tableView.tableFooterView = nil
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastSection = tableView.numberOfSections - 1
        let isLastRow = indexPath.section == lastSection
            && indexPath.row == tableView.numberOfRows(inSection: lastSection) - 1
        if isLastRow {
            Task { await viewModel.loadMore() }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let transaction = dataSource.itemIdentifier(for: indexPath) else { return }
        present(TransactionDetailViewController.sheet(for: transaction), animated: true)
    }

    // MARK: - Montagem

    private func makeDataSource() -> DataSource {
        DataSource(tableView: tableView) { tableView, indexPath, transaction in
            let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.reuseID, for: indexPath)
            (cell as? TransactionCell)?.configure(with: transaction)
            return cell
        }
    }

    private func makeProblemBanner(_ problem: NodeProblem) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: problem.symbol))
        icon.tintColor = .systemOrange
        let label = UILabel()
        label.text = problem.message
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 6
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = .init(top: 8, leading: 20, bottom: 0, trailing: 20)
        row.isAccessibilityElement = true
        row.accessibilityLabel = problem.message
        row.frame.size = row.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        return row
    }

    private func makeEmptyState() -> UIView {
        let label = UILabel()
        label.text = String(localized: "Nenhuma transação ainda.\nQuando você enviar ou receber CC, elas aparecem aqui.")
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}

// MARK: - Fonte de dados com cabeçalho por dia

private final class ActivityDataSource: UITableViewDiffableDataSource<Date, TransactionSummary> {
    private let calendar = Calendar.current

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let day = sectionIdentifier(for: section) ?? .now
        if calendar.isDateInToday(day) { return String(localized: "Hoje") }
        if calendar.isDateInYesterday(day) { return String(localized: "Ontem") }
        let sameYear = calendar.isDate(day, equalTo: .now, toGranularity: .year)
        return sameYear
            ? day.formatted(.dateTime.day().month(.wide))
            : day.formatted(.dateTime.day().month(.wide).year())
    }
}

// MARK: - Célula

private final class TransactionCell: UITableViewCell {
    static let reuseID = "TransactionCell"
    private let row = TransactionRowView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .surface
        accessoryType = .disclosureIndicator
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) não é usado")
    }

    func configure(with transaction: TransactionSummary) {
        row.configure(with: transaction, subtitle: .block)
        accessibilityLabel = row.accessibilityLabel
        accessibilityTraits = .button
    }
}
