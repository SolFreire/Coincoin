import Combine
import Foundation

@MainActor
final class ActivityViewModel: ObservableObject {

    struct DaySection: Hashable {
        let day: Date
        let items: [TransactionSummary]
    }

    @Published private(set) var sections: [DaySection] = []
    @Published private(set) var problem: NodeProblem?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasMore = false

    let wallet: Address
    private let node: any NodeClient
    private let pageSize: Int
    private let calendar: Calendar

    private var items: [TransactionSummary] = []
    private var nextBefore: UInt64?

    init(node: any NodeClient, wallet: Address, pageSize: Int = 30, calendar: Calendar = .current) {
        self.node = node
        self.wallet = wallet
        self.pageSize = pageSize
        self.calendar = calendar
    }

    /// Recomeça do topo: a primeira página reflete os blocos mais novos.
    func refresh() async {
        await fetchPage(before: nil, replacing: true)
    }

    /// Próxima página, a partir do cursor. Não faz nada se não houver mais.
    func loadMore() async {
        guard let cursor = nextBefore else { return }
        await fetchPage(before: cursor, replacing: false)
    }

    private func fetchPage(before cursor: UInt64?, replacing: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await node.transactions(of: wallet, before: cursor, limit: pageSize)
            let fetched = page.items.map { TransactionSummary(record: $0, viewer: wallet) }

            if replacing {
                items = fetched
            } else {
                let known = Set(items.map(\.id))
                items += fetched.filter { !known.contains($0.id) }
            }
            nextBefore = page.nextBefore
            hasMore = page.nextBefore != nil
            hasLoaded = true
            problem = nil
            sections = group(items)
        } catch {
            if let problem = NodeProblem(error) {
                self.problem = problem
            }
        }
    }

    private func group(_ items: [TransactionSummary]) -> [DaySection] {
        var sections: [DaySection] = []
        for item in items {
            let day = calendar.startOfDay(for: item.date)
            if let last = sections.last, last.day == day {
                sections[sections.count - 1] = DaySection(day: day, items: last.items + [item])
            } else {
                sections.append(DaySection(day: day, items: [item]))
            }
        }
        return sections
    }
}
