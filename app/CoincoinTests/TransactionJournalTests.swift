//
//  TransactionJournalTests.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation
import Testing
@testable import Coincoin

nonisolated struct FailingJournal: TransactionJournal {
    func load() throws -> [JournalEntry] { [] }
    func save(_ entries: [JournalEntry]) throws { throw CocoaError(.fileWriteOutOfSpace) }
}

nonisolated struct UnreadableJournal: TransactionJournal {
    func load() throws -> [JournalEntry] { throw CocoaError(.fileReadCorruptFile) }
    func save(_ entries: [JournalEntry]) throws {
        Issue.record("Um registro ilegível nunca pode ser sobrescrito")
    }
}

struct TransactionJournalTests {

    static let bob = Address(hex: String(repeating: "b0", count: 20))!

    let signer = InMemorySigner()

    func node(balance: UInt64 = 100) -> MockNodeClient {
        MockNodeClient(balances: [signer.address: Amount(balance)])
    }

    // MARK: - Recuperação depois de uma queda

    @Test func appReabertoLembraDoEnvioDesconhecidoEResolve() async throws {
        let node = node()
        let journal = InMemoryJournal()
        await node.failNextSubmits(.dropResponse)
        _ = try await TransactionTracker(node: node, signer: signer, journal: journal).send(Amount(30), to: Self.bob)

        let reopened = TransactionTracker(node: node, signer: signer, journal: journal)

        #expect(await reopened.transactions.first?.phase == .unknown)
        #expect(await reopened.outgoingPending == Amount(30))
        await reopened.refresh()
        #expect(await reopened.transactions.first?.phase == .pending)
    }

    @Test func quedaEntreGravarEEnviarReenviaOsBytesGravados() async throws {
        let node = node()
        let journal = InMemoryJournal()
        let envelope = try await signer.envelope(for: TransferPayload(to: Self.bob, amount: Amount(30), nonce: 0))
        try journal.save([JournalEntry(
            payload: envelope.payload, signature: envelope.signature, publicKey: envelope.publicKey, phase: .sending)])

        let reopened = TransactionTracker(node: node, signer: signer, journal: journal)
        #expect(await reopened.transactions.first?.phase == .unknown)

        await reopened.refresh()
        #expect(try await node.status(of: envelope.hash).state == .pending)
    }

    // MARK: - Write-ahead

    @Test func semConseguirGravarNaoEnvia() async throws {
        let node = node()
        let tracker = TransactionTracker(node: node, signer: signer, journal: FailingJournal())

        await #expect(throws: SendError.storageFailed) {
            try await tracker.send(Amount(30), to: Self.bob)
        }
        #expect(await tracker.transactions.isEmpty)

        await node.mineBlock()
        #expect(try await node.account(Self.bob).balance == Amount(0))
    }

    @Test func registroIlegivelBloqueiaEnviosSemApagar() async throws {
        let tracker = TransactionTracker(node: node(), signer: signer, journal: UnreadableJournal())

        await #expect(throws: SendError.storageFailed) {
            try await tracker.send(Amount(30), to: Self.bob)
        }
    }

    // MARK: - Conteúdo do registro

    @Test func confirmadaSaiDoRegistro() async throws {
        let node = node()
        let journal = InMemoryJournal()
        let tracker = TransactionTracker(node: node, signer: signer, journal: journal)

        _ = try await tracker.send(Amount(30), to: Self.bob)
        #expect(try journal.load().map(\.phase) == [.pending])

        await node.mineBlock()
        await tracker.refresh()
        #expect(try journal.load().isEmpty)
    }

    @Test func registroDeOutraChaveEIgnorado() async throws {
        let other = InMemorySigner()
        let node = MockNodeClient(balances: [other.address: Amount(100)])
        let journal = InMemoryJournal()
        _ = try await TransactionTracker(node: node, signer: other, journal: journal).send(Amount(10), to: Self.bob)

        let tracker = TransactionTracker(node: node, signer: signer, journal: journal)

        #expect(await tracker.transactions.isEmpty)
    }

    @Test func arquivoEmDiscoSobreviveAoReabrir() async throws {
        let url = URL.temporaryDirectory.appending(path: "coincoin-\(UUID().uuidString)/transactions.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let node = node()
        await node.failNextSubmits(.dropResponse)
        _ = try await TransactionTracker(node: node, signer: signer, journal: FileJournal(url: url))
            .send(Amount(30), to: Self.bob)

        let reopened = TransactionTracker(node: node, signer: signer, journal: FileJournal(url: url))

        #expect(await reopened.transactions.first?.phase == .unknown)
    }
}
