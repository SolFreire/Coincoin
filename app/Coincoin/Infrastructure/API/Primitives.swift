import Foundation

// Tipos pequenos que dão nome e regra a valores que, na rede, são só números e strings.
// Cada um valida o formato ao ser criado, inclusive quando vem de um JSON do nó:
// nada que chega da rede é confiável, nem para o app.

/// Valor monetário em Coincoins. Inteiro sem sinal; nunca ponto flutuante.
///
/// É um tipo próprio, e não um `UInt64` solto, para o compilador impedir que um valor
/// seja confundido com um nonce ou uma altura, que também são `UInt64`.
nonisolated struct Amount: Hashable, Comparable, Sendable {
    let units: UInt64

    init(_ units: UInt64) {
        self.units = units
    }

    static func < (lhs: Amount, rhs: Amount) -> Bool {
        lhs.units < rhs.units
    }
}

extension Amount: Codable {
    // No JSON, um Amount é só o número: `"amount": 10`, não `"amount": {"units": 10}`.
    init(from decoder: Decoder) throws {
        units = try decoder.singleValueContainer().decode(UInt64.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(units)
    }
}

/// Endereço de conta: 40 caracteres hexadecimais minúsculos (20 bytes).
nonisolated struct Address: Hashable, Sendable {
    let hex: String

    /// Falha (`nil`) se o texto não estiver exatamente no formato do contrato.
    init?(hex: String) {
        guard HexFormat.isValid(hex, length: 40) else { return nil }
        self.hex = hex
    }
}

/// Hash de transação: 64 caracteres hexadecimais minúsculos (SHA-256).
nonisolated struct TxHash: Hashable, Sendable {
    let hex: String

    init?(hex: String) {
        guard HexFormat.isValid(hex, length: 64) else { return nil }
        self.hex = hex
    }
}

extension Address: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let address = Address(hex: text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Endereço fora do formato (40 hex minúsculos): \(text)")
        }
        self = address
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

extension TxHash: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let hash = TxHash(hex: text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Hash fora do formato (64 hex minúsculos): \(text)")
        }
        self = hash
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

nonisolated private enum HexFormat {
    static func isValid(_ text: String, length: Int) -> Bool {
        text.utf8.count == length && text.utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
        }
    }
}
