//
//  PaymentRequest.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation

nonisolated struct PaymentRequest: Hashable, Sendable {
    static let scheme = "coincoin"

    let address: Address
    let amount: Amount?

    init(address: Address, amount: Amount? = nil) {
        self.address = address
        self.amount = amount
    }

    var uri: String {
        var text = "\(Self.scheme):\(address.hex)"
        if let amount {
            text += "?amount=\(amount.units)"
        }
        return text
    }

    init?(scanned text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let address = Address(hex: trimmed.lowercased()) {
            self.init(address: address)
            return
        }

        let prefix = Self.scheme + ":"
        guard trimmed.lowercased().hasPrefix(prefix) else { return nil }
        let rest = trimmed.dropFirst(prefix.count)

        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard let address = Address(hex: parts[0].lowercased()) else { return nil }

        var amount: Amount?
        if parts.count == 2 {
            for pair in parts[1].split(separator: "&") {
                let field = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard field.count == 2 else { return nil }
                switch field[0] {
                case "amount":
                    guard amount == nil,
                          field[1].allSatisfy({ $0.isASCII && $0.isNumber }),
                          let units = UInt64(field[1]), units > 0
                    else { return nil }
                    amount = Amount(units)
                case let name where name.hasPrefix("req-"):
                    return nil
                default:
                    continue
                }
            }
        }
        self.init(address: address, amount: amount)
    }
}
