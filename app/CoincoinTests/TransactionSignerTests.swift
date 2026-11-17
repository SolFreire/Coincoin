//
//  TransactionSignerTests.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 17/11/26.
//

import CryptoKit
import Foundation
import Testing
@testable import Coincoin

struct TransactionSignerTests {

    let signer = InMemorySigner()
    let payload = Data(#"{"amount":10,"nonce":0,"type":"transfer"}"#.utf8)

    func isValid(_ signature: Data, for payload: Data, publicKeyDER: Data) throws -> Bool {
        let key = try P256.Signing.PublicKey(derRepresentation: publicKeyDER)
        let ecdsa = try P256.Signing.ECDSASignature(derRepresentation: signature)
        return key.isValidSignature(ecdsa, for: payload)
    }

    @Test func assinaturaConfereComAChavePublica() async throws {
        let signature = try await signer.sign(payload)
        #expect(try isValid(signature, for: payload, publicKeyDER: signer.publicKeyDER))
    }

    @Test func mesmoPayloadGeraAssinaturasDiferentesEAmbasValidas() async throws {
        let first = try await signer.sign(payload)
        let second = try await signer.sign(payload)

        #expect(first != second)
        #expect(try isValid(first, for: payload, publicKeyDER: signer.publicKeyDER))
        #expect(try isValid(second, for: payload, publicKeyDER: signer.publicKeyDER))
    }

    @Test func payloadAlteradoInvalidaAAssinatura() async throws {
        let signature = try await signer.sign(payload)
        var tampered = payload
        tampered[tampered.startIndex] ^= 0x01

        #expect(try isValid(signature, for: tampered, publicKeyDER: signer.publicKeyDER) == false)
    }

    @Test func assinarOHashEmVezDoPayloadNaoConfere() async throws {
        let signature = try await signer.sign(Data(SHA256.hash(data: payload)))
        #expect(try isValid(signature, for: payload, publicKeyDER: signer.publicKeyDER) == false)
    }

    @Test func chavePublicaTem91Bytes() {
        #expect(signer.publicKeyDER.count == 91)
    }

    @Test func envelopeAssinaExatamenteOsBytesEnviados() async throws {
        let bob = Address(hex: String(repeating: "b0", count: 20))!
        let transfer = TransferPayload(to: bob, amount: Amount(10), nonce: 0)

        let envelope = try await signer.envelope(for: transfer)

        #expect(envelope.publicKey == signer.publicKeyDER)
        #expect(try isValid(envelope.signature, for: envelope.payload, publicKeyDER: envelope.publicKey))
        #expect(envelope.hash == TxHash(sha256Of: try transfer.encodedBytes()))
        #expect(try APICoding.makeDecoder().decode(TransferPayload.self, from: envelope.payload) == transfer)
    }
}
