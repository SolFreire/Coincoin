//
//  SendViewModel.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Combine
import Foundation

@MainActor
final class SendViewModel: ObservableObject {

    enum AddressIssue: Equatable {
        case invalid
        case ownAddress
    }

    enum AmountIssue: Equatable {
        case notANumber
        case zero
        case exceedsAvailable
    }

    enum Status: Equatable {
        case editing
        case sending
        case sent(TrackedTransaction)
        case failed(SendError)
    }

    @Published var addressText = "" {
        didSet { validate() }
    }
    @Published var amountText = "" {
        didSet { validate() }
    }
    @Published private(set) var addressIssue: AddressIssue?
    @Published private(set) var amountIssue: AmountIssue?
    @Published private(set) var status: Status = .editing

    let available: Amount
    private let wallet: Address
    private let tracker: TransactionTracker
    private var recipient: Address?
    private var amount: Amount?

    init(tracker: TransactionTracker, wallet: Address, available: Amount) {
        self.tracker = tracker
        self.wallet = wallet
        self.available = available
    }

    var canSend: Bool {
        recipient != nil && amount != nil && status != .sending
    }

    func send() async {
        guard let recipient, let amount, status != .sending else { return }
        status = .sending
        do {
            status = .sent(try await tracker.send(amount, to: recipient))
        } catch .cancelled, .busy {
            status = .editing
        } catch {
            status = .failed(error)
        }
    }
    
    func applyScanned(_ text: String) -> Bool {
        guard let request = PaymentRequest(scanned: text) else { return false }
        addressText = request.address.hex
        if let amount = request.amount {
            amountText = String(amount.units)
        }
        return true
    }


    private func validate() {
        if case .failed = status {
            status = .editing
        }

        let hex = addressText.filter { !$0.isWhitespace }.lowercased()
        switch Address(hex: hex) {
        case nil:
            recipient = nil
            addressIssue = hex.isEmpty ? nil : .invalid
        case let address? where address == wallet:
            recipient = nil
            addressIssue = .ownAddress
        case let address?:
            recipient = address
            addressIssue = nil
        }

        let digits = amountText.filter { !$0.isWhitespace }
        if digits.isEmpty {
            amount = nil
            amountIssue = nil
        } else if !digits.allSatisfy(\.isASCIIDigit) {
            amount = nil
            amountIssue = .notANumber
        } else if let units = UInt64(digits), units > 0, Amount(units) <= available {
            amount = Amount(units)
            amountIssue = nil
        } else {
            amount = nil
            amountIssue = UInt64(digits) == 0 ? .zero : .exceedsAvailable
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

extension SendViewModel.AddressIssue {
    var message: String {
        switch self {
        case .invalid: String(localized: "Endereço inválido: são 40 caracteres de 0 a 9 e de a a f.")
        case .ownAddress: String(localized: "Esse é o endereço desta carteira.")
        }
    }
}

extension SendViewModel.AmountIssue {
    var message: String {
        switch self {
        case .notANumber: String(localized: "Use só números inteiros.")
        case .zero: String(localized: "O valor precisa ser maior que zero.")
        case .exceedsAvailable: String(localized: "Maior que o saldo disponível.")
        }
    }
}

@MainActor
extension SendError {
    var userMessage: String {
        switch self {
        case .busy, .cancelled:
            ""
        case .unresolvedPrevious:
            String(localized: "Ainda estamos conferindo um envio anterior. Tente de novo em instantes.")
        case .signingFailed(.keyUnavailable):
            String(localized: "A chave desta carteira não pode ser aberta neste aparelho.")
        case .signingFailed:
            String(localized: "Não foi possível assinar a transferência.")
        case .rejected(let apiError) where apiError.code == .insufficientFunds:
            String(localized: "O nó recusou: saldo insuficiente.")
        case .rejected(let apiError):
            String(localized: "O nó recusou a transferência (\(apiError.code.rawValue)).")
        case .node(let error):
            NodeProblem(error)?.message ?? String(localized: "Não foi possível falar com o nó.")
        case .storageFailed:
            String(localized: "Não foi possível guardar o envio neste aparelho. Nada foi enviado.")
        }
    }
}
