import Foundation

nonisolated protocol NodeClient: Sendable {
    func health() async throws(NodeClientError) -> HealthResponse
    func account(_ address: Address) async throws(NodeClientError) -> AccountResponse
    func transactions(of address: Address, before: UInt64?, limit: Int) async throws(NodeClientError) -> TxListResponse
    func status(of hash: TxHash) async throws(NodeClientError) -> TxStatusResponse
    func submit(_ envelope: TransactionEnvelope) async throws(NodeClientError) -> TxStatusResponse
}


nonisolated enum NodeClientError: Error, Hashable, Sendable {

    case rejected(APIError)
    case timedOut
    case unreachable
    case invalidResponse
    case cancelled
    var outcomeIsUnknown: Bool {
        self == .timedOut || self == .cancelled
    }
}
