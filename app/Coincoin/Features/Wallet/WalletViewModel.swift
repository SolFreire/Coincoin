import Combine
import Foundation

@MainActor
final class WalletViewModel: ObservableObject {

    struct Snapshot: Equatable {
        let availableBalance: Amount
        let nodeId: String
        let height: UInt64
        let recent: [TransactionSummary]
        let fetchedAt: Date
    }

    /// Último estado lido com sucesso. Continua visível quando uma atualização falha.
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var problem: NodeProblem?
    @Published private(set) var isLoading = false

    let wallet: Address
    let tracker: TransactionTracker
    private let node: any NodeClient
    private let recentLimit: Int
    private let now: () -> Date

    init(
        node: any NodeClient,
        tracker: TransactionTracker,
        wallet: Address,
        recentLimit: Int = 5,
        now: @escaping () -> Date = Date.init
    ) {
        self.node = node
        self.tracker = tracker
        self.wallet = wallet
        self.recentLimit = recentLimit
        self.now = now
    }
    
    func makeSendViewModel() -> SendViewModel {
        SendViewModel(tracker: tracker, wallet: wallet, available: snapshot?.availableBalance ?? Amount(0))
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await tracker.refresh()
        let outgoing = await tracker.outgoingPending
        let local = await tracker.transactions.compactMap { TransactionSummary(tracked: $0, date: now()) }

        do {
            async let health = node.health()
            async let account = node.account(wallet)
            async let history = node.transactions(of: wallet, before: nil, limit: recentLimit)
            let (healthResponse, accountResponse, historyResponse) = try await (health, account, history)

            let localIDs = Set(local.map(\.id))
            let confirmed = historyResponse.items
                .map { TransactionSummary(record: $0, viewer: wallet) }
                .filter { !localIDs.contains($0.id) }
            let balance = accountResponse.balance.units

            snapshot = Snapshot(
                availableBalance: Amount(balance > outgoing.units ? balance - outgoing.units : 0),
                nodeId: healthResponse.nodeId,
                height: healthResponse.height,
                recent: Array((local + confirmed).prefix(recentLimit)),
                fetchedAt: now())
            problem = nil
        } catch {
            if let problem = NodeProblem(error) {
                self.problem = problem
            }
        }
    }
    
}
