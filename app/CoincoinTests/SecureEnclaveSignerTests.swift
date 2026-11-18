//
//  SecureEnclaveSignerTest.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import CryptoKit
import Foundation
import Testing
@testable import Coincoin

struct SecureEnclaveSignerTests {
    let store = KeychainStore(service: "personalproject.Coincoin.tests", account: UUID().uuidString)

    @Test func semChaveGuardadaNaoHaCarteira() throws {
        #expect(try SecureEnclaveSigner.load(from: store) == nil)
    }

    @Test func blocoQueOChipNaoAbreViraCarteiraInacessivel() throws {
        defer { try? store.delete() }
        try store.add(Data("bloco de outro aparelho".utf8))

        #expect(throws: SignerError.keyUnavailable) {
            try SecureEnclaveSigner.load(from: store)
        }
    }

    @Test func keychainNaoSobrescreveUmaChaveExistente() throws {
        defer { try? store.delete() }
        try store.add(Data([1]))

        #expect(throws: KeychainError.alreadyExists) {
            try store.add(Data([2]))
        }
        #expect(try store.read() == Data([1]))
    }
}

@Suite(.enabled(if: SecureEnclave.isAvailable, "Exige Secure Enclave disponível"))
struct SecureEnclaveHardwareTests {
    let store = KeychainStore(service: "personalproject.Coincoin.tests", account: UUID().uuidString)

    func makeSigner() throws -> SecureEnclaveSigner {
        try SecureEnclaveSigner.create(in: store, flags: [.privateKeyUsage])
    }

    @Test func reabreAMesmaChaveDepoisDeGuardada() throws {
        defer { try? store.delete() }
        let created = try makeSigner()

        let loaded = try #require(try SecureEnclaveSigner.load(from: store))

        #expect(loaded.address == created.address)
        #expect(loaded.publicKeyDER.count == 91)
    }

    @Test func assinaturaConfereComAChavePublica() async throws {
        defer { try? store.delete() }
        let signer = try makeSigner()
        let payload = Data("coincoin".utf8)

        let signature = try await signer.sign(payload)

        let publicKey = try P256.Signing.PublicKey(derRepresentation: signer.publicKeyDER)
        let ecdsa = try P256.Signing.ECDSASignature(derRepresentation: signature)
        #expect(publicKey.isValidSignature(ecdsa, for: payload))
    }

    @Test func segundaCriacaoNaoApagaAPrimeira() throws {
        defer { try? store.delete() }
        let first = try makeSigner()

        #expect(throws: SignerError.failed) {
            try makeSigner()
        }
        #expect(try SecureEnclaveSigner.load(from: store)?.address == first.address)
    }
}
