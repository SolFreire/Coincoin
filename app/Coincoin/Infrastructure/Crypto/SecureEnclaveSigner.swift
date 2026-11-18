//
//  SecureEnclaveSigner.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

nonisolated struct SecureEnclaveSigner: TransactionSigner {
    private let keyData: Data
    let publicKeyDER: Data

    private init(keyData: Data, publicKeyDER: Data) {
        self.keyData = keyData
        self.publicKeyDER = publicKeyDER
    }

    static func create(
        in store: KeychainStore = .wallet,
        flags: SecAccessControlCreateFlags = [.privateKeyUsage, .userPresence]
    ) throws(SignerError) -> SecureEnclaveSigner {
        guard SecureEnclave.isAvailable,
              let access = SecAccessControlCreateWithFlags(
                  nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, flags, nil)
        else {
            throw .failed
        }
        do {
            let key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
            try store.add(key.dataRepresentation)
            return SecureEnclaveSigner(
                keyData: key.dataRepresentation, publicKeyDER: key.publicKey.derRepresentation)
        } catch {
            throw .failed
        }
    }

    static func load(from store: KeychainStore = .wallet) throws(SignerError) -> SecureEnclaveSigner? {
        let stored: Data?
        do {
            stored = try store.read()
        } catch {
            throw .failed
        }
        guard let stored else { return nil }

        do {
            let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: stored)
            return SecureEnclaveSigner(keyData: stored, publicKeyDER: key.publicKey.derRepresentation)
        } catch {
            throw .keyUnavailable
        }
    }

    @concurrent
    func sign(_ payload: Data) async throws(SignerError) -> Data {
        let context = LAContext()
        context.localizedReason = String(localized: "Assinar a transferência")
        do {
            let key = try SecureEnclave.P256.Signing.PrivateKey(
                dataRepresentation: keyData, authenticationContext: context)
            return try key.signature(for: payload).derRepresentation
        } catch {
            throw Self.isCancellation(error) ? .cancelled : .failed
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        let cancelCodes: Set<Int> = [
            LAError.Code.userCancel.rawValue,
            LAError.Code.appCancel.rawValue,
            LAError.Code.systemCancel.rawValue,
        ]
        var current: NSError? = error as NSError
        while let nsError = current {
            if nsError.domain == LAError.errorDomain, cancelCodes.contains(nsError.code) {
                return true
            }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }
}
