import Foundation
import Testing
@testable import Coincoin

/// Comportamento do nó simulado: regras do contrato e, principalmente, falhas de rede.
struct MockNodeClientTests {

    // Chaves "públicas" de mentira: o mock ainda não verifica assinaturas (passo 6),
    // só deriva o endereço do remetente a partir delas, como manda o contrato.
    static let aliceKey = Data("chave-publica-alice".utf8)
    static let alice = Address(publicKeyDER: aliceKey)
    static let bob = Address(hex: String(repeating: "b0", count: 20))!

    func transfer(_ amount: UInt64, nonce: UInt64, to: Address = bob) throws -> TransactionEnvelope {
        let payload = TransferPayload(to: to, amount: Amount(amount), nonce: nonce)
        return TransactionEnvelope(payload: try payload.encodedBytes(), signature: Data(), publicKey: Self.aliceKey)
    }

    func node(aliceBalance: UInt64 = 100) -> MockNodeClient {
        MockNodeClient(balances: [Self.alice: Amount(aliceBalance)])
    }

    // MARK: - 3b: leitura

    @Test func contaDesconhecidaTemSaldoENonceZero() async throws {
        let account = try await node().account(Self.bob)
        #expect(account.balance == Amount(0))
        #expect(account.nextNonce == 0)
    }

    @Test func statusDeHashDesconhecidoETxNotFound() async throws {
        let unknown = TxHash(sha256Of: Data("nada".utf8))
        await #expect(throws: NodeClientError.rejected(APIError(code: .txNotFound, message: "Transação desconhecida"))) {
            try await node().status(of: unknown)
        }
    }

    // MARK: - 3c: envio e bloco

    @Test func envioFicaPendenteEConfirmaNoBloco() async throws {
        let node = node()
        let envelope = try transfer(30, nonce: 0)

        let sent = try await node.submit(envelope)
        #expect(sent.state == .pending)
        #expect(sent.hash == envelope.hash)

        await node.mineBlock()

        #expect(try await node.status(of: envelope.hash).state == .confirmed(height: 1))
        #expect(try await node.account(Self.alice).balance == Amount(70))
        #expect(try await node.account(Self.alice).nextNonce == 1)
        #expect(try await node.account(Self.bob).balance == Amount(30))
    }

    @Test func reenvioDosMesmosBytesEIdempotente() async throws {
        let node = node()
        let envelope = try transfer(30, nonce: 0)

        let first = try await node.submit(envelope)
        let second = try await node.submit(envelope)
        await node.mineBlock()
        let afterBlock = try await node.submit(envelope)

        #expect(first.hash == second.hash)
        #expect(afterBlock.state == .confirmed(height: 1))
        // Debitado uma vez só, apesar de três envios.
        #expect(try await node.account(Self.alice).balance == Amount(70))
    }

    @Test func saldoInsuficienteERecusadoNoEnvio() async throws {
        let error = await #expect(throws: NodeClientError.self) {
            try await node(aliceBalance: 10).submit(transfer(50, nonce: 0))
        }
        #expect(error == .rejected(APIError(code: .insufficientFunds, message: "Saldo insuficiente")))
    }

    @Test func nonceForaDeOrdemERecusado() async throws {
        let error = await #expect(throws: NodeClientError.self) {
            try await node().submit(transfer(10, nonce: 3))
        }
        guard case .rejected(let apiError) = error else {
            Issue.record("Esperava rejeição, veio \(String(describing: error))")
            return
        }
        #expect(apiError.code == .invalidNonce)
    }

    @Test func duasPendentesGastandoOMesmoSaldoOBlocoDecide() async throws {
        // Gasto duplo: as duas passam no envio (o saldo confirmado é 100 nas duas
        // checagens), mas só a primeira cabe no bloco. A ordem resolve o conflito.
        let node = node(aliceBalance: 100)
        let first = try transfer(80, nonce: 0)
        let second = try transfer(80, nonce: 1)

        _ = try await node.submit(first)
        _ = try await node.submit(second)
        await node.mineBlock()

        #expect(try await node.status(of: first.hash).state == .confirmed(height: 1))
        #expect(try await node.status(of: second.hash).state == .failed(.insufficientFunds))
        #expect(try await node.account(Self.alice).balance == Amount(20))
        #expect(try await node.account(Self.alice).nextNonce == 2)
    }

    @Test func historicoTemSoConfirmadasDaMaisNovaParaAMaisAntigaComPaginas() async throws {
        let node = node()
        for nonce in 0..<3 {
            _ = try await node.submit(transfer(1, nonce: UInt64(nonce)))
            await node.mineBlock()
        }
        _ = try await node.submit(transfer(1, nonce: 3))  // pendente: não aparece

        let firstPage = try await node.transactions(of: Self.alice, before: nil, limit: 2)
        #expect(firstPage.items.map(\.nonce) == [2, 1])
        #expect(firstPage.nextBefore == 2)

        let lastPage = try await node.transactions(of: Self.alice, before: firstPage.nextBefore, limit: 2)
        #expect(lastPage.items.map(\.nonce) == [0])
        #expect(lastPage.nextBefore == nil)

        // Bob aparece como destinatário das mesmas transações.
        #expect(try await node.transactions(of: Self.bob, before: nil, limit: 10).items.count == 3)
    }

    // MARK: - 3d: falhas de rede

    @Test func latenciaMaiorQueOTimeoutDaTimeout() async throws {
        let node = MockNodeClient(behavior: .init(latency: .milliseconds(50), timeout: .milliseconds(5)))
        await #expect(throws: NodeClientError.timedOut) {
            try await node.health()
        }
    }

    @Test func semConexaoNadaEExecutado() async throws {
        let node = node()
        let envelope = try transfer(30, nonce: 0)
        await node.failNextCalls(.unreachable)

        await #expect(throws: NodeClientError.unreachable) {
            try await node.submit(envelope)
        }
        // O pedido não chegou: o nó não conhece a transação.
        await #expect(throws: NodeClientError.self) {
            try await node.status(of: envelope.hash)
        }
    }

    @Test func respostaPerdidaMasATransacaoExisteERecuperavel() async throws {
        // O cenário central da disciplina: o nó executou, a resposta se perdeu.
        let node = node()
        let envelope = try transfer(30, nonce: 0)
        await node.failNextCalls(.dropResponse)

        let error = await #expect(throws: NodeClientError.self) {
            try await node.submit(envelope)
        }
        #expect(error == .timedOut)
        #expect(error?.outcomeIsUnknown == true)

        // Timeout não é falha: a transação existe. O app recupera de dois jeitos.
        #expect(try await node.status(of: envelope.hash).state == .pending)   // consultando
        #expect(try await node.submit(envelope).state == .pending)            // reenviando os mesmos bytes

        await node.mineBlock()
        #expect(try await node.account(Self.alice).balance == Amount(70))      // debitado uma vez
    }

    @Test func noSincronizandoRecusaComCodigoDoContrato() async throws {
        let node = node()
        await node.failNextCalls(.reject(.syncing))
        await #expect(throws: NodeClientError.rejected(APIError(code: .syncing, message: "Falha programada no mock"))) {
            try await node.account(Self.alice)
        }
        // A falha programada vale só para a próxima chamada.
        #expect(try await node.account(Self.alice).balance == Amount(100))
    }

    @Test func chamadasConcorrentesNaoGastamODobro() async throws {
        // Dez envios simultâneos do mesmo envelope, com latência: o actor serializa o
        // estado e a idempotência garante um único débito.
        let node = MockNodeClient(
            balances: [Self.alice: Amount(100)], behavior: .init(latency: .milliseconds(2)))
        let envelope = try transfer(30, nonce: 0)

        try await withThrowingTaskGroup(of: TxStatusResponse.self) { group in
            for _ in 0..<10 {
                group.addTask { try await node.submit(envelope) }
            }
            for try await response in group {
                #expect(response.hash == envelope.hash)
            }
        }
        await node.mineBlock()
        #expect(try await node.account(Self.alice).balance == Amount(70))
    }
}
