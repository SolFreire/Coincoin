//
//  WalletLoader.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 19/11/26.
//

import CryptoKit
import Foundation
import LocalAuthentication

nonisolated enum WalletState: Sendable {
    case none
    case ready(any TransactionSigner)
    case unavailable
    case unsupported
}

nonisolated struct WalletLoader: Sendable {
    let store: KeychainStore
    let keyFlags: SecAccessControlCreateFlags
    let canHoldKey: @Sendable () -> Bool

    init(
        store: KeychainStore = .wallet,
        keyFlags: SecAccessControlCreateFlags = [.privateKeyUsage, .userPresence],
        canHoldKey: @escaping @Sendable () -> Bool = WalletLoader.deviceCanHoldKey
    ) {
        self.store = store
        self.keyFlags = keyFlags
        self.canHoldKey = canHoldKey
    }
    
    static func deviceCanHoldKey() -> Bool {
        #if targetEnvironment(simulator)
        false
        #else
        SecureEnclave.isAvailable
            && LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        #endif
    }

    func load() -> WalletState {
        guard canHoldKey() else { return .unsupported }
        do {
            guard let signer = try SecureEnclaveSigner.load(from: store) else { return .none }
            return .ready(signer)
        } catch {
            return .unavailable
        }
    }

    func create() throws(SignerError) -> any TransactionSigner {
        guard canHoldKey() else { throw .failed }
        return try SecureEnclaveSigner.create(in: store, flags: keyFlags)
    }

    func replace() throws(SignerError) -> any TransactionSigner {
        guard canHoldKey() else { throw .failed }
        do {
            try store.delete()
        } catch {
            throw .failed
        }
        return try create()
    }
}
