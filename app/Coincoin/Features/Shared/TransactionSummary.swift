import Foundation

/// Uma transação vista pela carteira: o lado "de lá" é sempre a contraparte.
nonisolated struct TransactionSummary: Hashable, Identifiable, Sendable {
    enum Direction: Hashable {
        case sent, received
    }

    let id: TxHash
    let direction: Direction
    let counterparty: Address
    let amount: Amount
    let nonce: UInt64
    let state: TxState
    let date: Date

    var height: UInt64? {
        if case .confirmed(let height) = state { return height }
        return nil
    }
}

extension TransactionSummary {
    init(record: TxRecord, viewer: Address) {
        let sent = record.from == viewer
        self.init(
            id: record.hash,
            direction: sent ? .sent : .received,
            counterparty: sent ? record.to : record.from,
            amount: record.amount,
            nonce: record.nonce,
            state: record.state,
            date: record.timestamp)
    }
}
