import Foundation

nonisolated struct DemoEnvironment: Sendable {
    let node: DemoNodeClient
    let wallet: Address

    static let walletKey = Data("carteira-demo".utf8)
    static let faucetKey = Data("torneira-demo".utf8)
    static let friendKey = Data("amigo-demo".utf8)

    static func make(now: Date = .now) -> DemoEnvironment {
        let wallet = Address(publicKeyDER: walletKey)
        let mock = MockNodeClient(
            nodeId: "demo",
            balances: [Address(publicKeyDER: faucetKey): Amount(1_000_000)])

        let ready = Task {
            await seed(mock, wallet: wallet, now: now)
            await mock.setBehavior(.init(latency: .milliseconds(400), timeout: .seconds(5)))
        }
        return DemoEnvironment(node: DemoNodeClient(base: mock, ready: ready), wallet: wallet)
    }

    private static func seed(_ mock: MockNodeClient, wallet: Address, now: Date) async {
        let friend = Address(publicKeyDER: friendKey)
        let history: [(key: Data, to: Address, amount: UInt64, nonce: UInt64, daysAgo: Double)] = [
            (faucetKey, wallet, 1_120, 0, 5),
            (walletKey, friend, 120, 0, 3),
            (faucetKey, wallet, 300, 1, 1),
            (walletKey, friend, 50, 1, 0.1),
        ]
        for entry in history {
            let payload = TransferPayload(to: entry.to, amount: Amount(entry.amount), nonce: entry.nonce)
            guard let bytes = try? payload.encodedBytes() else { continue }
            _ = try? await mock.submit(TransactionEnvelope(payload: bytes, signature: Data(), publicKey: entry.key))
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
