//
//  TransactionTrackerTests.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation
import Testing
@testable import Coincoin

nonisolated struct CancellingSigner: TransactionSigner {
    let base = InMemorySigner()
    var publicKeyDER: Data { base.publicKeyDER }

    func sign(_ payload: Data) async throws(SignerError) -> Data {
        throw .cancelled
    }
}

nonisolated struct SlowSigner: TransactionSigner {
    let base: InMemorySigner
    var publicKeyDER: Data { base.publicKeyDER }

    func sign(_ payload: Data) async throws(SignerError) -> Data {
        try? await Task.sleep(for: .milliseconds(100))
        return try await base.sign(payload)
    }
}

struct TransactionTrackerTests {

    static let bob = Address(hex: String(repeating: "b0", count: 20))!

    func setup(balance: UInt64 = 100) -> (MockNodeClient, TransactionTracker) {
        let signer = InMemorySigner()
        let node = MockNodeClient(balances: [signer.address: Amount(balance)])
        return (node, TransactionTracker(node: node, signer: signer))
    }

    // MARK: - Caminho normal

    @Test func envioAceitoFicaPendenteEDepoisConfirma() async throws {
        let (node, tracker) = setup()

        let sent = try await tracker.send(Amount(30), to: Self.bob)
        #expect(sent.phase == .pending)
        #expect(await tracker.outgoingPending == Amount(30))

        await node.mineBlock()
        await tracker.refresh()

        #expect(await tracker.transactions.first?.phase == .confirmed(height: 1))
        #expect(await tracker.outgoingPending == Amount(0))
    }

    @Test func segundoEnvioUsaONonceSeguinteAoPendente() async throws {
        let (node, tracker) = setup()

        _ = try await tracker.send(Amount(10), to: Self.bob)
        let second = try await tracker.send(Amount(10), to: Self.bob)

        #expect(second.transfer.nonce == 1)
        await node.mineBlock()
        await tracker.refresh()
        #expect(await tracker.transactions.allSatisfy { $0.phase == .confirmed(height: 1) })
    }

    // MARK: - Resultado desconhecido

    @Test func respostaPerdidaNaoEFalhaEAConsultaDescobreQueChegou() async throws {
        let (node, tracker) = setup()
        await node.failNextSubmits(.dropResponse)

        let sent = try await tracker.send(Amount(30), to: Self.bob)
        #expect(sent.phase == .unknown)
        #expect(await tracker.outgoingPending == Amount(30))

        await tracker.refresh()
        #expect(await tracker.transactions.first?.phase == .pending)

        await node.mineBlock()
        #expect(try await node.account(Self.bob).balance == Amount(30))
    }

    @Test func pedidoQueNaoChegouEReenviadoComOsMesmosBytes() async throws {
        let (node, tracker) = setup()
        await node.failNextSubmits(.timeout)

        let sent = try await tracker.send(Amount(30), to: Self.bob)
        #expect(sent.phase == .unknown)

        await tracker.refresh()

        #expect(await tracker.transactions.first?.phase == .pending)
        #expect(try await node.status(of: sent.id).state == .pending)
    }

    @Test func desconhecidoEResolvidoAntesDoProximoEnvio() async throws {
        let (node, tracker) = setup()
        await node.failNextSubmits(.dropResponse)

        let first = try await tracker.send(Amount(10), to: Self.bob)
        let second = try await tracker.send(Amount(10), to: Self.bob)

        #expect(first.transfer.nonce == 0)
        #expect(second.transfer.nonce == 1)
    }

    @Test func naoEnviaPorCimaDeUmDesconhecidoNaoResolvido() async throws {
        let (node, tracker) = setup()
        await node.failNextSubmits(.dropResponse)
        _ = try await tracker.send(Amount(10), to: Self.bob)

        await node.failNextCalls(.unreachable)

        await #expect(throws: SendError.unresolvedPrevious) {
            try await tracker.send(Amount(10), to: Self.bob)
        }
    }

    // MARK: - Falhas conhecidas

    @Test func semConexaoNoEnvioViraErroENadaFicaPendurado() async throws {
        let (node, tracker) = setup()
        await node.failNextSubmits(.unreachable)

        await #expect(throws: SendError.node(.unreachable)) {
            try await tracker.send(Amount(10), to: Self.bob)
        }
        #expect(await tracker.transactions.isEmpty)
    }

    @Test func recusaDoNoViraErroENaoDescontaSaldo() async throws {
        let (_, tracker) = setup(balance: 5)

        await #expect(throws: SendError.rejected(APIError(code: .insufficientFunds, message: "Saldo insuficiente"))) {
            try await tracker.send(Amount(10), to: Self.bob)
        }
        #expect(await tracker.outgoingPending == Amount(0))
    }

    @Test func faceIDCanceladoNaoEnviaNada() async throws {
        let signer = CancellingSigner()
        let node = MockNodeClient(balances: [signer.address: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: signer)

        await #expect(throws: SendError.cancelled) {
            try await tracker.send(Amount(10), to: Self.bob)
        }
        #expect(await tracker.transactions.isEmpty)
    }

    // MARK: - Concorrência

    @Test func doisEnviosAoMesmoTempoOSegundoERecusado() async throws {
        let base = InMemorySigner()
        let node = MockNodeClient(balances: [base.address: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: SlowSigner(base: base))

        async let first = tracker.send(Amount(10), to: Self.bob)
        try await Task.sleep(for: .milliseconds(20))

        await #expect(throws: SendError.busy) {
            try await tracker.send(Amount(10), to: Self.bob)
        }
        #expect(try await first.transfer.nonce == 0)
    }
}
