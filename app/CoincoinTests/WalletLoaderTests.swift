//
//  WalletLoaderTests.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 19/11/26.
//

import CryptoKit
import Foundation
import Testing
@testable import Coincoin

struct WalletLoaderTests {

    let store = KeychainStore(service: "personalproject.Coincoin.tests", account: UUID().uuidString)

    func loader(canHoldKey: Bool = true) -> WalletLoader {
        WalletLoader(store: store, canHoldKey: { canHoldKey })
    }

    @Test func semNadaGuardadoNaoHaCarteira() {
        guard case .none = loader().load() else {
            Issue.record("Esperava .none")
            return
        }
    }

    @Test func blocoQueOChipNaoAbreECarteiraInacessivel() throws {
        defer { try? store.delete() }
        try store.add(Data("bloco de outro aparelho".utf8))

        guard case .unavailable = loader().load() else {
            Issue.record("Esperava .unavailable")
            return
        }
    }

    @Test func aparelhoSemCondicaoDeGuardarChaveENaoSuportado() throws {
        defer { try? store.delete() }
        try store.add(Data("qualquer".utf8))

        guard case .unsupported = loader(canHoldKey: false).load() else {
            Issue.record("Esperava .unsupported")
            return
        }
        #expect(throws: SignerError.failed) {
            try loader(canHoldKey: false).create()
        }
    }

    @Test(.enabled(if: SecureEnclave.isAvailable, "Exige Secure Enclave disponível"))
    func chaveGuardadaECarregada() throws {
        defer { try? store.delete() }
        let created = try SecureEnclaveSigner.create(in: store, flags: [.privateKeyUsage])

        guard case .ready(let signer) = loader().load() else {
            Issue.record("Esperava .ready")
            return
        }
        #expect(signer.address == created.address)
    }
}
