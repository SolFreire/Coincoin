//
//  OnboardingViewModel.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 19/11/26.
//

import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {

    enum Mode: Equatable {
        case create
        case demoOnly
        case unavailable
    }

    let mode: Mode
    @Published private(set) var failed = false
    private let loader: WalletLoader

    init?(state: WalletState, loader: WalletLoader) {
        switch state {
        case .ready: return nil
        case .none: mode = .create
        case .unsupported: mode = .demoOnly
        case .unavailable: mode = .unavailable
        }
        self.loader = loader
    }

    func start() -> (any TransactionSigner)? {
        do {
            let signer: any TransactionSigner = switch mode {
            case .create: try loader.create()
            case .demoOnly: InMemorySigner()
            case .unavailable: try loader.replace()
            }
            failed = false
            return signer
        } catch {
            failed = true
            return nil
        }
    }
}
