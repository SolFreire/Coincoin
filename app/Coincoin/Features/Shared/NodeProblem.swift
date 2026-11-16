import UIKit

/// O que a tela precisa saber sobre uma falha do nó.
enum NodeProblem: Equatable {
    case unreachable
    case syncing
    case rejected(APIErrorCode)
    case invalidResponse

    /// `nil` quando a falha não deve aparecer para o usuário (cancelamento pelo próprio app).
    init?(_ error: any Error) {
        guard let error = error as? NodeClientError else {
            self = .invalidResponse
            return
        }
        switch error {
        case .unreachable, .timedOut:
            self = .unreachable
        case .rejected(let apiError) where apiError.code == .syncing:
            self = .syncing
        case .rejected(let apiError):
            self = .rejected(apiError.code)
        case .invalidResponse:
            self = .invalidResponse
        case .cancelled:
            return nil
        }
    }

    var message: String {
        switch self {
        case .unreachable: String(localized: "Sem conexão com o nó")
        case .syncing: String(localized: "Nó sincronizando")
        case .rejected, .invalidResponse: String(localized: "O nó respondeu com erro")
        }
    }

    var symbol: String {
        switch self {
        case .unreachable: "wifi.exclamationmark"
        case .syncing: "arrow.triangle.2.circlepath"
        case .rejected, .invalidResponse: "exclamationmark.triangle"
        }
    }
}
