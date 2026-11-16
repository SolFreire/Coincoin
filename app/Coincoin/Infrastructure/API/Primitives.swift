import Foundation

// Tipos pequenos que dão nome e regra a valores que, na rede, são só números e strings.
// Cada um valida o formato ao ser criado, inclusive quando vem de um JSON do nó:
// nada que chega da rede é confiável, nem para o app.


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

    init(from decoder: Decoder) throws {
        units = try decoder.singleValueContainer().decode(UInt64.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(units)
    }
}


nonisolated struct Address: Hashable, Sendable {
    let hex: String

    init?(hex: String) {
        guard HexFormat.isValid(hex, length: 40) else { return nil }
        self.hex = hex
    }
}


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
