//
//  TransactionTracker.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation

nonisolated struct TrackedTransaction: Hashable, Identifiable, Sendable {
    enum Phase: Codable, Hashable, Sendable {
        case sending
        case unknown
        case pending
        case confirmed(height: UInt64)
        case failed(APIErrorCode)
    }

    let envelope: TransactionEnvelope
    let transfer: TransferPayload
    var phase: Phase

    var id: TxHash { envelope.hash }

    var isOpen: Bool {
        switch phase {
        case .sending, .unknown, .pending: true
        case .confirmed, .failed: false
        }
    }
}

nonisolated enum SendError: Error, Hashable, Sendable {
    case busy
    case unresolvedPrevious
    case cancelled
    case signingFailed(SignerError)
    case rejected(APIError)
    case node(NodeClientError)
    case storageFailed
}

actor TransactionTracker {
    private let node: any NodeClient
    private let signer: any TransactionSigner
    private let journal: any TransactionJournal
    private var tracked: [TxHash: TrackedTransaction]
    private let journalIsUnreadable: Bool
    private var isSending = false

    init(node: any NodeClient, signer: any TransactionSigner, journal: any TransactionJournal = InMemoryJournal()) {
        self.node = node
        self.signer = signer
        self.journal = journal

        var restored: [TxHash: TrackedTransaction] = [:]
        var unreadable = false
        do {
            for entry in try journal.load() where entry.publicKey == signer.publicKeyDER {
                if let transaction = TrackedTransaction(restoring: entry) {
                    restored[transaction.id] = transaction
                }
            }
        } catch {
            unreadable = true
        }
        self.tracked = restored
        self.journalIsUnreadable = unreadable
    }

    var transactions: [TrackedTransaction] {
        tracked.values.sorted { $0.transfer.nonce > $1.transfer.nonce }
    }

    var outgoingPending: Amount {
        Amount(tracked.values.filter(\.isOpen).reduce(0) { $0 + $1.transfer.amount.units })
    }

    func send(_ amount: Amount, to recipient: Address) async throws(SendError) -> TrackedTransaction {
        guard !journalIsUnreadable else { throw .storageFailed }
        guard !isSending else { throw .busy }
        isSending = true
        defer { isSending = false }

        await refresh()
        guard !tracked.values.contains(where: { $0.phase == .unknown }) else {
            throw .unresolvedPrevious
        }

        let account: AccountResponse
        do {
            account = try await node.account(signer.address)
        } catch {
            throw .node(error)
        }

        let transfer = TransferPayload(to: recipient, amount: amount, nonce: nextNonce(after: account))
        let envelope: TransactionEnvelope
        do {
            envelope = try await signer.envelope(for: transfer)
        } catch .cancelled {
            throw .cancelled
        } catch {
            throw .signingFailed(error)
        }

        let transaction = TrackedTransaction(envelope: envelope, transfer: transfer, phase: .sending)
        tracked[transaction.id] = transaction
        do {
            try persist()
        } catch {
            tracked[transaction.id] = nil
            throw .storageFailed
        }
        return try await deliver(transaction)
    }

    func refresh() async {
        for transaction in tracked.values where transaction.phase == .unknown || transaction.phase == .pending {
            await check(transaction)
        }
    }

    private func nextNonce(after account: AccountResponse) -> UInt64 {
        let highestOpen = tracked.values.filter(\.isOpen).map(\.transfer.nonce).max()
        return max(account.nextNonce, highestOpen.map { $0 + 1 } ?? 0)
    }

    private func deliver(_ transaction: TrackedTransaction) async throws(SendError) -> TrackedTransaction {
        do {
            let response = try await node.submit(transaction.envelope)
            return update(transaction, to: Self.phase(of: response.state))
        } catch .rejected(let apiError) {
            tracked[transaction.id] = nil
            try? persist()
            throw .rejected(apiError)
        } catch let error where error.outcomeIsUnknown {
            return update(transaction, to: .unknown)
        } catch {
            tracked[transaction.id] = nil
            try? persist()
            throw .node(error)
        }
    }

    private func check(_ transaction: TrackedTransaction) async {
        do {
            let response = try await node.status(of: transaction.id)
            update(transaction, to: Self.phase(of: response.state))
        } catch .rejected(let apiError) where apiError.code == .txNotFound && transaction.phase == .unknown {
            _ = try? await deliver(transaction)
        } catch {
            return
        }
    }

    @discardableResult
    private func update(_ transaction: TrackedTransaction, to phase: TrackedTransaction.Phase) -> TrackedTransaction {
        var updated = transaction
        updated.phase = phase
        tracked[updated.id] = updated
        try? persist()
        return updated
    }

    private func persist() throws {
        guard !journalIsUnreadable else { throw CocoaError(.fileReadCorruptFile) }
        let entries = tracked.values
            .filter { if case .confirmed = $0.phase { false } else { true } }
            .sorted { $0.transfer.nonce < $1.transfer.nonce }
            .map(JournalEntry.init)
        try journal.save(entries)
    }

    private static func phase(of state: TxState) -> TrackedTransaction.Phase {
        switch state {
        case .pending: .pending
        case .confirmed(let height): .confirmed(height: height)
        case .failed(let code): .failed(code)
        }
    }
}

nonisolated extension TrackedTransaction {
    fileprivate init?(restoring entry: JournalEntry) {
        guard let transfer = try? APICoding.makeDecoder().decode(TransferPayload.self, from: entry.payload) else {
            return nil
        }
        self.init(
            envelope: TransactionEnvelope(payload: entry.payload, signature: entry.signature, publicKey: entry.publicKey),
            transfer: transfer,
            phase: entry.phase == .sending ? .unknown : entry.phase)
    }
}

nonisolated extension JournalEntry {
    fileprivate init(_ transaction: TrackedTransaction) {
        self.init(
            payload: transaction.envelope.payload,
            signature: transaction.envelope.signature,
            publicKey: transaction.envelope.publicKey,
            phase: transaction.phase)
    }
}
