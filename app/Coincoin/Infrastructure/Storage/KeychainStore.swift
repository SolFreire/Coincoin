//
//  KeychainStore.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation
import Security

nonisolated enum KeychainError: Error, Equatable {
    case alreadyExists
    case unexpected(OSStatus)
}

nonisolated struct KeychainStore: Sendable {
    let service: String
    let account: String

    static let wallet = KeychainStore(service: "personalproject.Coincoin.wallet", account: "signing-key")

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read() throws(KeychainError) -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw .unexpected(status)
        }
    }

    func add(_ data: Data) throws(KeychainError) {
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            throw .alreadyExists
        default:
            throw .unexpected(status)
        }
    }

    func delete() throws(KeychainError) {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .unexpected(status)
        }
    }
}
