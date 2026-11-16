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
    private let node: any NodeClient
    private let recentLimit: Int
    private let now: () -> Date

    init(node: any NodeClient, wallet: Address, recentLimit: Int = 5, now: @escaping () -> Date = Date.init) {
        self.node = node
        self.wallet = wallet
        self.recentLimit = recentLimit
        self.now = now
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let health = node.health()
            async let account = node.account(wallet)
            async let history = node.transactions(of: wallet, before: nil, limit: recentLimit)
            let (healthResponse, accountResponse, historyResponse) = try await (health, account, history)

            snapshot = Snapshot(
                // TODO(passo 7): descontar as saídas pendentes do TransactionTracker.
                availableBalance: accountResponse.balance,
                nodeId: healthResponse.nodeId,
                height: healthResponse.height,
                recent: historyResponse.items.map { TransactionSummary(record: $0, viewer: wallet) },
                fetchedAt: now())
            problem = nil
        } catch {
            if let problem = NodeProblem(error) {
                self.problem = problem
            }
        }
    }
}
