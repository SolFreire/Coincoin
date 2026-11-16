import Combine
import Foundation

struct RecentTransaction: Equatable, Identifiable {
    enum Direction: Equatable {
        case sent, received
    }

    let id: TxHash
    let direction: Direction
    let counterparty: Address
    let amount: Amount
    let date: Date
}

@MainActor
final class WalletViewModel: ObservableObject {

    struct Snapshot: Equatable {
        let availableBalance: Amount
        let nodeId: String
        let height: UInt64
        let recent: [RecentTransaction]
        let fetchedAt: Date
    }

    enum Problem: Equatable {
        case unreachable
        case syncing
        case rejected(APIErrorCode)
        case invalidResponse
    }

    /// Último estado lido com sucesso. Continua visível quando uma atualização falha.
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var problem: Problem?
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
                recent: historyResponse.items.map(recentTransaction),
                fetchedAt: now())
            problem = nil
        } catch let error as NodeClientError {
            if let problem = Self.problem(for: error) {
                self.problem = problem
            }
        } catch {
            problem = .invalidResponse
        }
    }

    private func recentTransaction(from record: TxRecord) -> RecentTransaction {
        let sent = record.from == wallet
        return RecentTransaction(
            id: record.hash,
            direction: sent ? .sent : .received,
            counterparty: sent ? record.to : record.from,
            amount: record.amount,
            date: record.timestamp)
    }

    private static func problem(for error: NodeClientError) -> Problem? {
        switch error {
        case .unreachable, .timedOut:
            return .unreachable
        case .rejected(let apiError) where apiError.code == .syncing:
            return .syncing
        case .rejected(let apiError):
            return .rejected(apiError.code)
        case .invalidResponse:
            return .invalidResponse
        case .cancelled:
            return nil
        }
    }
}
