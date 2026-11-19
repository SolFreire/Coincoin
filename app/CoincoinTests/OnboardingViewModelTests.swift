import CryptoKit
import Foundation
import Testing
@testable import Coincoin

@MainActor
struct OnboardingViewModelTests {

    let store = KeychainStore(service: "personalproject.Coincoin.tests", account: UUID().uuidString)

    func loader(canHoldKey: Bool = true) -> WalletLoader {
        WalletLoader(store: store, keyFlags: [.privateKeyUsage], canHoldKey: { canHoldKey })
    }

    @Test func cadaEstadoTemSuaTela() {
        #expect(OnboardingViewModel(state: .none, loader: loader())?.mode == .create)
        #expect(OnboardingViewModel(state: .unsupported, loader: loader())?.mode == .demoOnly)
        #expect(OnboardingViewModel(state: .unavailable, loader: loader())?.mode == .unavailable)
        #expect(OnboardingViewModel(state: .ready(InMemorySigner()), loader: loader()) == nil)
    }

    @Test func demonstracaoNaoGuardaNada() throws {
        let viewModel = try #require(OnboardingViewModel(state: .unsupported, loader: loader(canHoldKey: false)))

        #expect(viewModel.start() is InMemorySigner)
        #expect(try store.read() == nil)
    }

    @Test(.enabled(if: SecureEnclave.isAvailable, "Exige Secure Enclave disponível"))
    func criarGuardaACarteira() throws {
        defer { try? store.delete() }
        let viewModel = try #require(OnboardingViewModel(state: .none, loader: loader()))

        let signer = try #require(viewModel.start())

        guard case .ready(let loaded) = loader().load() else {
            Issue.record("A carteira criada deveria carregar")
            return
        }
        #expect(loaded.address == signer.address)
    }

    @Test(.enabled(if: SecureEnclave.isAvailable, "Exige Secure Enclave disponível"))
    func carteiraInacessivelESubstituida() throws {
        defer { try? store.delete() }
        try store.add(Data("bloco de outro aparelho".utf8))
        let viewModel = try #require(OnboardingViewModel(state: loader().load(), loader: loader()))
        #expect(viewModel.mode == .unavailable)

        let signer = try #require(viewModel.start())

        guard case .ready(let loaded) = loader().load() else {
            Issue.record("A carteira nova deveria carregar")
            return
        }
        #expect(loaded.address == signer.address)
    }

    @Test(.enabled(if: SecureEnclave.isAvailable, "Exige Secure Enclave disponível"))
    func criarNuncaSobrescreveUmaCarteiraExistente() throws {
        defer { try? store.delete() }
        let existing = try loader().create()
        let viewModel = try #require(OnboardingViewModel(state: .none, loader: loader()))

        #expect(viewModel.start() == nil)
        #expect(viewModel.failed)
        guard case .ready(let loaded) = loader().load() else {
            Issue.record("A carteira existente deveria continuar")
            return
        }
        #expect(loaded.address == existing.address)
    }
}
