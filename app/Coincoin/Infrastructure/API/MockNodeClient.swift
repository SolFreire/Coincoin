import Foundation

/// Nó Coincoin falso, em memória, com latência e falhas configuráveis.

actor MockNodeClient: NodeClient {


    enum Failure: Sendable {
        case unreachable
        case timeout
        case dropResponse
        case reject(APIErrorCode)
    }

    struct Behavior: Sendable {
        var latency: Duration = .zero
        var timeout: Duration = .seconds(10)
    }

    let nodeId: String
    private(set) var behavior: Behavior
    private var scheduledFailures: [Failure] = []



    private struct StoredTx {
        let hash: TxHash
        let from: Address
        let payload: TransferPayload
        let sequence: Int
        var state: TxState
        var timestamp: Date?
    }

    private var balances: [Address: Amount]
    private var nextNonces: [Address: UInt64] = [:]
    private var height: UInt64 = 0
    private var transactions: [TxHash: StoredTx] = [:]
    private var arrivalCount = 0

    init(nodeId: String = "mock", balances: [Address: Amount] = [:], behavior: Behavior = Behavior()) {
        self.nodeId = nodeId
        self.balances = balances
        self.behavior = behavior
    }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }


    func failNextCalls(_ failures: Failure...) {
        scheduledFailures.append(contentsOf: failures)
    }

    // MARK: - NodeClient

    func health() async throws(NodeClientError) -> HealthResponse {
        let dropsResponse = try await travel()
        let response = HealthResponse(nodeId: nodeId, status: .ok, height: height)
        return try deliver(response, dropping: dropsResponse)
    }

    func account(_ address: Address) async throws(NodeClientError) -> AccountResponse {
        let dropsResponse = try await travel()
        let response = AccountResponse(
            address: address,
            balance: balances[address] ?? Amount(0),
            nextNonce: nextNonces[address] ?? 0,
            height: height)
        return try deliver(response, dropping: dropsResponse)
    }

    func transactions(of address: Address, before: UInt64?, limit: Int) async throws(NodeClientError) -> TxListResponse {
        let dropsResponse = try await travel()

        let pageSize = min(max(limit, 1), 100)
        let confirmed = transactions.values
            .compactMap { tx -> (StoredTx, UInt64)? in
                guard case .confirmed(let blockHeight) = tx.state,
                      tx.from == address || tx.payload.to == address,
                      before.map({ blockHeight < $0 }) ?? true
                else { return nil }
                return (tx, blockHeight)
            }
            .sorted { ($0.1, $0.0.sequence) > ($1.1, $1.0.sequence) }  // mais nova primeiro

        let page = confirmed.prefix(pageSize)
        let hasMore = confirmed.count > pageSize
        let response = TxListResponse(
            items: page.map { tx, _ in record(of: tx) },
            nextBefore: hasMore ? page.last?.1 : nil)
        return try deliver(response, dropping: dropsResponse)
    }

    func status(of hash: TxHash) async throws(NodeClientError) -> TxStatusResponse {
        let dropsResponse = try await travel()
        guard let tx = transactions[hash] else {
            throw .rejected(APIError(code: .txNotFound, message: "Transação desconhecida"))
        }
        return try deliver(TxStatusResponse(hash: hash, state: tx.state), dropping: dropsResponse)
    }

    func submit(_ envelope: TransactionEnvelope) async throws(NodeClientError) -> TxStatusResponse {
        let dropsResponse = try await travel()

        let hash = envelope.hash
        if let known = transactions[hash] {
            return try deliver(TxStatusResponse(hash: hash, state: known.state), dropping: dropsResponse)
        }

        guard let payload = try? APICoding.makeDecoder().decode(TransferPayload.self, from: envelope.payload) else {
            throw .rejected(APIError(code: .malformed, message: "Payload inválido"))
        }

        let sender = Address(publicKeyDER: envelope.publicKey)

        let pendingFromSender = transactions.values.filter { $0.from == sender && $0.state == .pending }.count
        let expectedNonce = (nextNonces[sender] ?? 0) + UInt64(pendingFromSender)
        guard payload.nonce == expectedNonce else {
            throw .rejected(APIError(
                code: .invalidNonce, message: "Nonce \(payload.nonce); esperado \(expectedNonce)"))
        }


        guard payload.amount <= balances[sender] ?? Amount(0) else {
            throw .rejected(APIError(code: .insufficientFunds, message: "Saldo insuficiente"))
        }

        arrivalCount += 1
        transactions[hash] = StoredTx(
            hash: hash, from: sender, payload: payload, sequence: arrivalCount, state: .pending, timestamp: nil)
        return try deliver(TxStatusResponse(hash: hash, state: .pending), dropping: dropsResponse)
    }


    func mineBlock(at date: Date = .now) {
        height += 1
        let pending = transactions.values.filter { $0.state == .pending }.sorted { $0.sequence < $1.sequence }

        for var tx in pending {
            let senderBalance = balances[tx.from] ?? Amount(0)
            if tx.payload.amount <= senderBalance {
                balances[tx.from] = Amount(senderBalance.units - tx.payload.amount.units)
                balances[tx.payload.to] = Amount((balances[tx.payload.to] ?? Amount(0)).units + tx.payload.amount.units)
                tx.state = .confirmed(height: height)
                tx.timestamp = date
            } else {
                tx.state = .failed(.insufficientFunds)
            }
            nextNonces[tx.from, default: 0] += 1
            transactions[tx.hash] = tx
        }
    }


    private func travel() async throws(NodeClientError) -> Bool {
        let failure = scheduledFailures.isEmpty ? nil : scheduledFailures.removeFirst()

        let wait = min(behavior.latency, behavior.timeout)
        if wait > .zero {
            do {
                try await Task.sleep(for: wait)
            } catch {
                throw .cancelled
            }
        }
        if behavior.latency > behavior.timeout {
            throw .timedOut
        }

        switch failure {
        case nil:
            return false
        case .unreachable:
            throw .unreachable
        case .timeout:
            throw .timedOut
        case .reject(let code):
            throw .rejected(APIError(code: code, message: "Falha programada no mock"))
        case .dropResponse:
            return true
        }
    }


    private func deliver<Response>(_ response: Response, dropping: Bool) throws(NodeClientError) -> Response {
        if dropping { throw .timedOut }
        return response
    }

    private func record(of tx: StoredTx) -> TxRecord {
        TxRecord(
            hash: tx.hash, from: tx.from, to: tx.payload.to, amount: tx.payload.amount,
            nonce: tx.payload.nonce, state: tx.state, timestamp: tx.timestamp ?? .distantPast)
    }
}
