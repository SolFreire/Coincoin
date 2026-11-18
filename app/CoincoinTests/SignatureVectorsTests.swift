//
//  SignatureVectorsTest.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import CryptoKit
import Foundation
import Testing
@testable import Coincoin

nonisolated struct SignatureVectors: Decodable {
    struct Sender: Decodable {
        let publicKey: Data
        let address: String
    }

    struct State: Decodable {
        let senderBalance: UInt64
    }

    struct Case: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let payload: Data
        let signature: Data
        let publicKey: Data
        let expected: String
        let hash: String?

        var testDescription: String { name }
    }

    let keys: [String: String]
    let sender: Sender
    let state: State
    let cases: [Case]

    static func load() throws -> SignatureVectors {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "testvectors/assinatura.json")
        return try JSONDecoder().decode(SignatureVectors.self, from: Data(contentsOf: url))
    }
}

struct SignatureVectorsTests {

    @Test func enderecoEChavePublicaSaemDaSemente() throws {
        let vectors = try SignatureVectors.load()
        let seed = try #require(vectors.keys["aliceSeed"])

        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: SHA256.hash(data: Data(seed.utf8)))
        let signer = InMemorySigner(privateKey: privateKey)

        #expect(signer.publicKeyDER == vectors.sender.publicKey)
        #expect(signer.address.hex == vectors.sender.address)
    }

    @Test(arguments: try SignatureVectors.load().cases)
    func mockChegaAoVeredictoDoVetor(_ vector: SignatureVectors.Case) async throws {
        let vectors = try SignatureVectors.load()
        let sender = Address(publicKeyDER: vectors.sender.publicKey)
        let node = MockNodeClient(balances: [sender: Amount(vectors.state.senderBalance)])
        let envelope = TransactionEnvelope(
            payload: vector.payload, signature: vector.signature, publicKey: vector.publicKey)

        do {
            let response = try await node.submit(envelope)
            #expect(vector.expected == "accepted")
            #expect(response.hash.hex == vector.hash)
        } catch .rejected(let error) {
            #expect(error.code.rawValue == vector.expected)
        }
    }
}
