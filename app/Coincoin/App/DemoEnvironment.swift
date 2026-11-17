import Foundation

nonisolated struct DemoEnvironment: Sendable {
    let node: DemoNodeClient
    let wallet: Address

    static let walletSigner = InMemorySigner()
    static let faucetSigner = InMemorySigner()
    static let friendSigner = InMemorySigner()

    static func make(now: Date = .now) -> DemoEnvironment {
        let wallet = walletSigner.address
        let mock = MockNodeClient(
            nodeId: "demo",
            balances: [faucetSigner.address: Amount(1_000_000)])

        let ready = Task {
            await seed(mock, wallet: wallet, now: now)
            await mock.setBehavior(.init(latency: .milliseconds(400), timeout: .seconds(5)))
        }
        return DemoEnvironment(node: DemoNodeClient(base: mock, ready: ready), wallet: wallet)
    }

    private static func seed(_ mock: MockNodeClient, wallet: Address, now: Date) async {
        let friend = friendSigner.address
        let history: [(signer: InMemorySigner, to: Address, amount: UInt64, nonce: UInt64, daysAgo: Double)] = [
            (faucetSigner, wallet, 1_120, 0, 5),
            (walletSigner, friend, 120, 0, 3),
            (faucetSigner, wallet, 300, 1, 1),
            (walletSigner, friend, 50, 1, 0.1),
        ]
        for entry in history {
            let payload = TransferPayload(to: entry.to, amount: Amount(entry.amount), nonce: entry.nonce)
            guard let envelope = try? await entry.signer.envelope(for: payload) else { continue }
            _ = try? await mock.submit(envelope)
            await mock.mineBlock(at: now.addingTimeInterval(-entry.daysAgo * 86_400))
        }
    }
}

/// Repassa as chamadas ao mock só depois que o histórico de demonstração foi carregado.
nonisolated struct DemoNodeClient: NodeClient {
    let base: MockNodeClient
    let ready: Task<Void, Never>

    func health() async throws(NodeClientError) -> HealthResponse {
        await ready.value
        return try await base.health()
    }

    func account(_ address: Address) async throws(NodeClientError) -> AccountResponse {
        await ready.value
        return try await base.account(address)
    }

    func transactions(of address: Address, before: UInt64?, limit: Int) async throws(NodeClientError) -> TxListResponse {
        await ready.value
        return try await base.transactions(of: address, before: before, limit: limit)
    }

    func status(of hash: TxHash) async throws(NodeClientError) -> TxStatusResponse {
        await ready.value
        return try await base.status(of: hash)
    }

    func submit(_ envelope: TransactionEnvelope) async throws(NodeClientError) -> TxStatusResponse {
        await ready.value
        return try await base.submit(envelope)
    }
}
