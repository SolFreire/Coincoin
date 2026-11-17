import Foundation
import Testing
@testable import Coincoin

@MainActor
struct ActivityViewModelTests {

    static let aliceSigner = InMemorySigner()
    static let alice = aliceSigner.address
    static let bob = Address(hex: String(repeating: "b0", count: 20))!
    static let day: TimeInterval = 86_400
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Uma transação por bloco, com as datas indicadas (em dias a partir de `start`).
    func node(blocksOnDays days: [Double]) async throws -> MockNodeClient {
        let node = MockNodeClient(balances: [Self.alice: Amount(1_000)])
        for (nonce, day) in days.enumerated() {
            try await send(on: node, nonce: UInt64(nonce))
            await node.mineBlock(at: Self.start.addingTimeInterval(day * Self.day))
        }
        return node
    }

    func send(on node: MockNodeClient, nonce: UInt64) async throws {
        let payload = TransferPayload(to: Self.bob, amount: Amount(1), nonce: nonce)
        _ = try await node.submit(Self.aliceSigner.envelope(for: payload))
    }

    func viewModel(_ node: MockNodeClient, pageSize: Int = 30) -> ActivityViewModel {
        ActivityViewModel(node: node, wallet: Self.alice, pageSize: pageSize, calendar: Self.utc)
    }

    func nonces(_ viewModel: ActivityViewModel) -> [UInt64] {
        viewModel.sections.flatMap(\.items).map(\.nonce)
    }

    // MARK: - Agrupamento

    @Test func agrupaPorDiaDoMaisNovoParaOMaisAntigo() async throws {
        let viewModel = viewModel(try await node(blocksOnDays: [0, 0.1, 2]))

        await viewModel.refresh()

        #expect(viewModel.sections.count == 2)
        #expect(viewModel.sections.map { $0.items.map(\.nonce) } == [[2], [1, 0]])
        #expect(viewModel.sections.first?.day == Self.utc.startOfDay(for: Self.start.addingTimeInterval(2 * Self.day)))
        #expect(viewModel.hasLoaded)
    }

    @Test func historicoVazioCarregaSemSecoes() async throws {
        let viewModel = viewModel(MockNodeClient())

        await viewModel.refresh()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.hasMore == false)
    }

    // MARK: - Paginação

    @Test func paginaAteOFim() async throws {
        let viewModel = viewModel(try await node(blocksOnDays: [0, 1, 2, 3, 4]), pageSize: 2)

        await viewModel.refresh()
        #expect(nonces(viewModel) == [4, 3])
        #expect(viewModel.hasMore)

        await viewModel.loadMore()
        await viewModel.loadMore()
        #expect(nonces(viewModel) == [4, 3, 2, 1, 0])
        #expect(viewModel.hasMore == false)

        await viewModel.loadMore()  // sem mais páginas: não faz nada
        #expect(nonces(viewModel).count == 5)
    }

    @Test func blocoNovoEntrePaginasNaoDuplicaNemPula() async throws {
        // Com paginação por posição ("pule 2"), o bloco novo deslocaria a lista e a
        // transação de nonce 2 apareceria de novo. Com cursor por altura, não.
        let node = try await node(blocksOnDays: [0, 1, 2, 3])
        let viewModel = viewModel(node, pageSize: 2)
        await viewModel.refresh()
        #expect(nonces(viewModel) == [3, 2])

        try await send(on: node, nonce: 4)
        await node.mineBlock(at: Self.start.addingTimeInterval(5 * Self.day))

        await viewModel.loadMore()
        #expect(nonces(viewModel) == [3, 2, 1, 0])

        await viewModel.refresh()  // o bloco novo só aparece ao recomeçar do topo
        #expect(nonces(viewModel) == [4, 3])
    }

    // MARK: - Falhas

    @Test func falhaAoCarregarMaisMantemOQueJaFoiLido() async throws {
        let node = try await node(blocksOnDays: [0, 1, 2, 3])
        let viewModel = viewModel(node, pageSize: 2)
        await viewModel.refresh()

        await node.failNextCalls(.unreachable)
        await viewModel.loadMore()

        #expect(nonces(viewModel) == [3, 2])
        #expect(viewModel.problem == .unreachable)
        #expect(viewModel.hasMore)

        await viewModel.loadMore()  // tenta de novo: o cursor não se perdeu
        #expect(nonces(viewModel) == [3, 2, 1, 0])
        #expect(viewModel.problem == nil)
    }

    // MARK: - Formatação

    @Test func hexAgrupadoDeQuatroEmQuatro() {
        #expect("a3f901bc77e2".groupedInFours() == "a3f9 01bc 77e2")
        #expect("a3f901".groupedInFours() == "a3f9 01")
    }
}
