import Foundation
import Testing
@testable import Coincoin

@MainActor
struct WalletViewModelTests {

    static let aliceSigner = InMemorySigner()
    static let alice = aliceSigner.address
    static let bob = Address(hex: String(repeating: "b0", count: 20))!
    static let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    func nodeWithOneTransfer(_ amount: UInt64 = 30) async throws -> MockNodeClient {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        let payload = TransferPayload(to: Self.bob, amount: Amount(amount), nonce: 0)
        _ = try await node.submit(Self.aliceSigner.envelope(for: payload))
        await node.mineBlock(at: Self.fixedNow)
        return node
    }

    func viewModel(
        _ node: MockNodeClient,
        wallet: Address? = nil,
        recentLimit: Int = 5,
        tracker: TransactionTracker? = nil
    ) -> WalletViewModel {
        WalletViewModel(
            node: node,
            tracker: tracker ?? TransactionTracker(node: node, signer: Self.aliceSigner),
            wallet: wallet ?? Self.alice,
            recentLimit: recentLimit,
            now: { Self.fixedNow })
    }

    // MARK: - Carregamento

    @Test func carregaSaldoNoEHistorico() async throws {
        let viewModel = viewModel(try await nodeWithOneTransfer())

        await viewModel.load()

        let snapshot = try #require(viewModel.snapshot)
        #expect(snapshot.availableBalance == Amount(70))
        #expect(snapshot.nodeId == "mock")
        #expect(snapshot.height == 1)
        #expect(snapshot.recent.map(\.direction) == [.sent])
        #expect(snapshot.recent.first?.counterparty == Self.bob)
        #expect(viewModel.problem == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func destinatarioVeComoRecebida() async throws {
        let viewModel = viewModel(try await nodeWithOneTransfer(), wallet: Self.bob)

        await viewModel.load()

        let recent = try #require(viewModel.snapshot?.recent.first)
        #expect(recent.direction == .received)
        #expect(recent.counterparty == Self.alice)
        #expect(recent.amount == Amount(30))
    }

    @Test func recentesRespeitaOLimite() async throws {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        for nonce in 0..<7 {
            let payload = TransferPayload(to: Self.bob, amount: Amount(1), nonce: UInt64(nonce))
            _ = try await node.submit(Self.aliceSigner.envelope(for: payload))
            await node.mineBlock()
        }
        let viewModel = viewModel(node, recentLimit: 5)

        await viewModel.load()

        #expect(viewModel.snapshot?.recent.count == 5)
    }

    // MARK: - Falhas

    @Test func primeiraCargaSemNoNaoTemDadosMasExplicaOProblema() async throws {
        let node = MockNodeClient()
        await node.failNextCalls(.unreachable)
        let viewModel = viewModel(node)

        await viewModel.load()

        #expect(viewModel.snapshot == nil)
        #expect(viewModel.problem == .unreachable)
    }

    @Test func falhaDepoisDeCarregarMantemOsDadosAntigos() async throws {
        let node = try await nodeWithOneTransfer()
        let viewModel = viewModel(node)
        await viewModel.load()
        let before = viewModel.snapshot

        await node.failNextCalls(.timeout)
        await viewModel.load()

        #expect(viewModel.snapshot == before)
        #expect(viewModel.problem == .unreachable)
    }

    @Test func noSincronizandoViraProblemaProprio() async throws {
        let node = try await nodeWithOneTransfer()
        await node.failNextCalls(.reject(.syncing))
        let viewModel = viewModel(node)

        await viewModel.load()

        #expect(viewModel.problem == .syncing)
    }

    @Test func recuperaQuandoONoVolta() async throws {
        let node = try await nodeWithOneTransfer()
        await node.failNextCalls(.unreachable)
        let viewModel = viewModel(node)

        await viewModel.load()
        #expect(viewModel.problem == .unreachable)

        await viewModel.load()
        #expect(viewModel.problem == nil)
        #expect(viewModel.snapshot?.availableBalance == Amount(70))
    }

    // MARK: - Formatação

    @Test func valoresEEnderecosFormatados() {
        let brazil = Locale(identifier: "pt_BR")
        #expect(Amount(1_250).displayText(locale: brazil) == "1.250")
        #expect(Amount(1_250).accessibilityText(locale: brazil) == "1250 Coincoins")
        #expect(Address(hex: "a3f9" + String(repeating: "0", count: 32) + "7c21")!.short == "a3f9…7c21")
    }
    
    // MARK: - Envios do próprio app

    @Test func saldoDisponivelDescontaOsEnviosAbertos() async throws {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: Self.aliceSigner)
        _ = try await tracker.send(Amount(30), to: Self.bob)
        let viewModel = viewModel(node, tracker: tracker)

        await viewModel.load()

        #expect(viewModel.snapshot?.availableBalance == Amount(70))
        #expect(viewModel.snapshot?.recent.first?.state == .pending)
        #expect(viewModel.snapshot?.recent.first?.isUncertain == false)
    }

    @Test func envioDesconhecidoApareceComoConferindo() async throws {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: Self.aliceSigner)
        await node.failNextSubmits(.dropResponse)
        _ = try await tracker.send(Amount(30), to: Self.bob)
        await node.failNextCalls(.unreachable)
        let viewModel = viewModel(node, tracker: tracker)

        await viewModel.load()

        let first = try #require(viewModel.snapshot?.recent.first)
        #expect(first.isUncertain)
        #expect(first.statusText == "Conferindo com o nó…")
        #expect(viewModel.snapshot?.availableBalance == Amount(70))
    }

    @Test func confirmadaNaoApareceDuasVezes() async throws {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: Self.aliceSigner)
        _ = try await tracker.send(Amount(30), to: Self.bob)
        await node.mineBlock(at: Self.fixedNow)
        let viewModel = viewModel(node, tracker: tracker)

        await viewModel.load()

        #expect(viewModel.snapshot?.recent.count == 1)
        #expect(viewModel.snapshot?.recent.first?.state == .confirmed(height: 1))
        #expect(viewModel.snapshot?.availableBalance == Amount(70))
    }
    
    @Test func sheetEnviarRecebeOSaldoDisponivel() async throws {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: Self.aliceSigner)
        _ = try await tracker.send(Amount(30), to: Self.bob)
        let viewModel = viewModel(node, tracker: tracker)

        #expect(viewModel.makeSendViewModel().available == Amount(0))
        await viewModel.load()
        #expect(viewModel.makeSendViewModel().available == Amount(70))
    }


    @Test func saldoDisponivelNuncaFicaNegativo() async throws {
        let node = MockNodeClient(balances: [Self.alice: Amount(100)])
        let tracker = TransactionTracker(node: node, signer: Self.aliceSigner)
        _ = try await tracker.send(Amount(80), to: Self.bob)
        _ = try await tracker.send(Amount(80), to: Self.bob)
        let viewModel = viewModel(node, tracker: tracker)

        await viewModel.load()

        #expect(viewModel.snapshot?.availableBalance == Amount(0))
    }

}
