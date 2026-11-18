import CryptoKit
import Foundation

func hex(_ data: some Sequence<UInt8>) -> String { data.map { String(format: "%02x", $0) }.joined() }
func b64(_ data: Data) -> String { data.base64EncodedString() }
func sha256(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }

func derKey(seed: String) throws -> P256.Signing.PrivateKey {
    try P256.Signing.PrivateKey(rawRepresentation: sha256(Data(seed.utf8)))
}

func payload(to: String, amount: UInt64, nonce: UInt64) -> Data {
    Data(#"{"amount":\#(amount),"nonce":\#(nonce),"to":"\#(to)","type":"transfer"}"#.utf8)
}

func malleated(_ der: Data) -> Data {
    let n: [UInt8] = [0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
                      0xbc,0xe6,0xfa,0xad,0xa7,0x17,0x9e,0x84,0xf3,0xb9,0xca,0xc2,0xfc,0x63,0x25,0x51]
    let bytes = [UInt8](der)
    var i = 2
    let rLen = Int(bytes[i + 1]); let r = Array(bytes[(i + 2)..<(i + 2 + rLen)]); i += 2 + rLen
    let sLen = Int(bytes[i + 1]); var s = Array(bytes[(i + 2)..<(i + 2 + sLen)])
    while s.count > 32 { s.removeFirst() }
    while s.count < 32 { s.insert(0, at: 0) }
    var out = [UInt8](repeating: 0, count: 32); var borrow = 0
    for k in stride(from: 31, through: 0, by: -1) {
        var d = Int(n[k]) - Int(s[k]) - borrow
        borrow = d < 0 ? 1 : 0; if d < 0 { d += 256 }
        out[k] = UInt8(d)
    }
    func integer(_ v: [UInt8]) -> [UInt8] {
        var v = v; while v.count > 1, v[0] == 0, v[1] < 0x80 { v.removeFirst() }
        if v[0] >= 0x80 { v.insert(0, at: 0) }
        return [0x02, UInt8(v.count)] + v
    }
    let body = [0x02, UInt8(r.count)] + r + integer(out)
    return Data([0x30, UInt8(body.count)] + body)
}

let alice = try derKey(seed: "coincoin/testvectors/alice")
let mallory = try derKey(seed: "coincoin/testvectors/mallory")
let alicePub = alice.publicKey.derRepresentation
let address = hex(sha256(alicePub).prefix(20))
let bob = String(repeating: "b0", count: 20)

let valid = payload(to: bob, amount: 10, nonce: 0)
let validSig = try alice.signature(for: valid).derRepresentation
let compressedSPKI = Data([0x30,0x39,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,0x22,0x00]) + alice.publicKey.compressedRepresentation
let notJSON = Data("isto não é um payload".utf8)
let wrongNonce = payload(to: bob, amount: 10, nonce: 9)

struct Case: Encodable {
    let name: String; let description: String
    let payload: String; let signature: String; let publicKey: String
    let expected: String; let hash: String?
}
func c(_ name: String, _ d: String, _ p: Data, _ s: Data, _ k: Data, _ e: String) -> Case {
    Case(name: name, description: d, payload: b64(p), signature: b64(s), publicKey: b64(k), expected: e,
         hash: e == "accepted" ? hex(sha256(p)) : nil)
}
struct File: Encodable {
    let description: String
    let keys: [String: String]
    let sender: [String: String]
    let state: [String: UInt64]
    let cases: [Case]
}
let mSig = malleated(validSig)
let mSigParsed = try P256.Signing.ECDSASignature(derRepresentation: mSig)
precondition(alice.publicKey.isValidSignature(mSigParsed, for: valid))
precondition(mSig != validSig)

let file = File(
    description: "Vetores de assinatura do Coincoin (api/contrato.md, seções Assinatura, Chave pública e Ordem de validação). Chaves de TESTE, públicas de propósito: privada = SHA-256 da semente.",
    keys: ["aliceSeed": "coincoin/testvectors/alice", "alicePrivateKeyRaw": hex(alice.rawRepresentation),
           "mallorySeed": "coincoin/testvectors/mallory"],
    sender: ["publicKey": b64(alicePub), "address": address],
    state: ["senderBalance": 1000, "senderNextNonce": 0],
    cases: [
        c("transferencia-valida", "Payload assinado pela própria chave.", valid, validSig, alicePub, "accepted"),
        c("assinatura-maleavel", "Mesmo payload com (r, n−s): também válida, mesmo hash.", valid, mSig, alicePub, "accepted"),
        c("payload-alterado", "Valor trocado de 10 para 90 depois de assinado.", payload(to: bob, amount: 90, nonce: 0), validSig, alicePub, "INVALID_SIGNATURE"),
        c("assinatura-de-outra-chave", "Mallory assina o payload e põe a chave de Alice.", valid, try mallory.signature(for: valid).derRepresentation, alicePub, "INVALID_SIGNATURE"),
        c("chave-ponto-comprimido", "Mesma chave de Alice em SPKI com ponto comprimido.", valid, validSig, compressedSPKI, "MALFORMED"),
        c("bytes-assinados-nao-sao-json", "Assinatura válida sobre bytes que não são um payload.", notJSON, try alice.signature(for: notJSON).derRepresentation, alicePub, "MALFORMED"),
        c("assinatura-invalida-e-nonce-errado", "Dois defeitos: vale o primeiro na ordem de validação.", wrongNonce, validSig, alicePub, "INVALID_SIGNATURE"),
    ])
let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
FileHandle.standardOutput.write(try enc.encode(file)); print()
