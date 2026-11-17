//
//  TransactionSigner.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 16/11/26.
//

import CryptoKit
import Foundation

nonisolated enum SignerError: Error, Equatable {
    case cancelled //user canceled
    case keyUnavailable //lost key
    case failed
}

nonisolated protocol TransactionSigner: Sendable {
    var publicKeyDER: Data { get }
    func sign(_ payload: Data) async throws(SignerError) -> Data
}

nonisolated extension TransactionSigner {
    var address: Address {
        Address(publicKeyDER: publicKeyDER)
    }

    func envelope(for transfer: TransferPayload) async throws(SignerError) -> TransactionEnvelope {
        let payload: Data
        do {
            payload = try transfer.encodedBytes()
        } catch {
            throw .failed
        }
        let signature = try await sign(payload)
        return TransactionEnvelope(payload: payload, signature: signature, publicKey: publicKeyDER)
    }
}

nonisolated struct InMemorySigner: TransactionSigner {
    private let privateKey: P256.Signing.PrivateKey

    init(privateKey: P256.Signing.PrivateKey = .init()) {
        self.privateKey = privateKey
    }

    var publicKeyDER: Data {
        privateKey.publicKey.derRepresentation
    }

    func sign(_ payload: Data) async throws(SignerError) -> Data {
        do {
            return try privateKey.signature(for: payload).derRepresentation
        } catch {
            throw .failed
        }
    }
}

