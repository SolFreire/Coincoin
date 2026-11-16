import CryptoKit
import Foundation



nonisolated enum APICoding {

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }


    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}


nonisolated enum TxState: Hashable, Sendable {
    case pending
    case confirmed(height: UInt64)
    case failed(APIErrorCode)
}

extension TxState {
    private enum Status: String, Decodable {
        case pending, confirmed, failed
    }


    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        status statusKey: Key,
        height heightKey: Key,
        failureCode failureKey: Key
    ) throws -> TxState {
        let status = try container.decode(Status.self, forKey: statusKey)
        let height = try container.decodeIfPresent(UInt64.self, forKey: heightKey)
        let failure = try container.decodeIfPresent(APIErrorCode.self, forKey: failureKey)

        switch (status, height, failure) {
        case (.pending, nil, nil):
            return .pending
        case let (.confirmed, height?, nil):
            return .confirmed(height: height)
        case let (.failed, nil, code?):
            return .failed(code)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: statusKey, in: container,
                debugDescription: "Combinação inválida: status \(status), height \(String(describing: height)), failureCode \(String(describing: failure))")
        }
    }
}


nonisolated struct TxStatusResponse: Hashable, Sendable {
    let hash: TxHash
    let state: TxState
}

extension TxStatusResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hash, status, height, failureCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hash = try container.decode(TxHash.self, forKey: .hash)
        state = try TxState.decode(from: container, status: .status, height: .height, failureCode: .failureCode)
    }
}


nonisolated struct AccountResponse: Decodable, Hashable, Sendable {
    let address: Address
    let balance: Amount
    let nextNonce: UInt64
    let height: UInt64
}

/// Um item de `GET /accounts/{address}/txs`.
nonisolated struct TxRecord: Hashable, Sendable {
    let hash: TxHash
    let from: Address
    let to: Address
    let amount: Amount
    let nonce: UInt64
    let state: TxState
    let timestamp: Date?
}

extension TxRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case hash, from, to, amount, nonce, status, height, failureCode, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hash = try container.decode(TxHash.self, forKey: .hash)
        from = try container.decode(Address.self, forKey: .from)
        to = try container.decode(Address.self, forKey: .to)
        amount = try container.decode(Amount.self, forKey: .amount)
        nonce = try container.decode(UInt64.self, forKey: .nonce)
        state = try TxState.decode(from: container, status: .status, height: .height, failureCode: .failureCode)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
    }
}

/// `GET /accounts/{address}/txs`.
nonisolated struct TxListResponse: Decodable, Hashable, Sendable {
    let items: [TxRecord]
    let nextBefore: UInt64?
}

/// `GET /health`.
nonisolated struct HealthResponse: Decodable, Hashable, Sendable {
    enum Status: String, Decodable, Sendable {
        case ok, syncing
    }

    let nodeId: String
    let status: Status
    let height: UInt64
}


nonisolated struct APIErrorCode: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let malformed = APIErrorCode(rawValue: "MALFORMED")
    static let invalidSignature = APIErrorCode(rawValue: "INVALID_SIGNATURE")
    static let insufficientFunds = APIErrorCode(rawValue: "INSUFFICIENT_FUNDS")
    static let invalidNonce = APIErrorCode(rawValue: "INVALID_NONCE")
    static let txNotFound = APIErrorCode(rawValue: "TX_NOT_FOUND")
    static let syncing = APIErrorCode(rawValue: "SYNCING")
}


nonisolated struct APIError: Error, Decodable, Hashable, Sendable {
    let code: APIErrorCode
    let message: String

    private enum OuterKeys: String, CodingKey { case error }
    private enum InnerKeys: String, CodingKey { case code, message }

    init(code: APIErrorCode, message: String) {
        self.code = code
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let inner = try decoder.container(keyedBy: OuterKeys.self)
            .nestedContainer(keyedBy: InnerKeys.self, forKey: .error)
        code = try inner.decode(APIErrorCode.self, forKey: .code)
        message = try inner.decode(String.self, forKey: .message)
    }
}



/// Payload de uma transferência, antes de virar bytes.
nonisolated struct TransferPayload: Encodable, Hashable, Sendable {
    let type = "transfer"
    let to: Address
    let amount: Amount
    let nonce: UInt64

    func encodedBytes() throws -> Data {
        try APICoding.makeEncoder().encode(self)
    }
}


nonisolated struct TransactionEnvelope: Encodable, Hashable, Sendable {
    let payload: Data
    let signature: Data
    let publicKey: Data


    var hash: TxHash {
        TxHash(sha256Of: payload)
    }
}

extension TxHash {

    nonisolated init(sha256Of data: Data) {
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        self.init(hex: hex)!
    }
}
