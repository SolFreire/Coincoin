import Foundation
import Testing
@testable import Coincoin

/// Confere que os modelos Swift leem e escrevem exatamente o formato de `api/contrato.md`.
/// Os JSONs aqui são os exemplos do contrato, com hashes e endereços de tamanho real.
///
/// Sem `@MainActor` de propósito: se algum modelo ficasse isolado na main thread,
/// estes testes não compilariam. Os modelos precisam ser decodificáveis em qualquer thread.
struct ContractDecodingTests {

    static let addressA = String(repeating: "a3", count: 20)
    static let addressB = String(repeating: "9b", count: 20)
    static let hash = String(repeating: "e4", count: 32)

    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APICoding.makeDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Primitivos

    @Test func amountAceitaOMaiorUInt64SemPerderPrecisao() throws {
        // JavaScript perderia precisão aqui (acima de 2^53); Swift e Go não podem perder.
        let account = try decode(AccountResponse.self, """
            {"address":"\(Self.addressA)","balance":18446744073709551615,"nextNonce":0,"height":0}
            """)
        #expect(account.balance == Amount(UInt64.max))
    }

    @Test func amountRejeitaNegativoEDecimal() {
        for invalid in ["-1", "10.5", "\"10\""] {
            #expect(throws: DecodingError.self) {
                try decode(AccountResponse.self, """
                    {"address":"\(Self.addressA)","balance":\(invalid),"nextNonce":0,"height":0}
                    """)
            }
        }
    }

    @Test(arguments: [
        String(repeating: "a", count: 39),          // curto
        String(repeating: "a", count: 41),          // longo
        String(repeating: "A", count: 40),          // maiúsculas
        String(repeating: "g", count: 40),          // não é hex
    ])
    func enderecoForaDoFormatoERejeitado(_ text: String) {
        #expect(Address(hex: text) == nil)
    }

    @Test func hashSHA256ConfereComVetorConhecido() {
        // Vetor de teste do FIPS 180-2: SHA-256("abc").
        let hash = TxHash(sha256Of: Data("abc".utf8))
        #expect(hash.hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // MARK: - Estado da transação

    @Test func txConfirmadaTemAltura() throws {
        let response = try decode(TxStatusResponse.self, """
            {"hash":"\(Self.hash)","status":"confirmed","height":1480,"failureCode":null}
            """)
        #expect(response.state == .confirmed(height: 1480))
    }

    @Test func txPendenteAceitaCamposAusentesOuNulos() throws {
        let semCampos = try decode(TxStatusResponse.self, #"{"hash":"\#(Self.hash)","status":"pending"}"#)
        let comNulos = try decode(TxStatusResponse.self, """
            {"hash":"\(Self.hash)","status":"pending","height":null,"failureCode":null}
            """)
        #expect(semCampos.state == .pending)
        #expect(comNulos.state == .pending)
    }

    @Test func txFalhaTrazOCodigo() throws {
        let response = try decode(TxStatusResponse.self, """
            {"hash":"\(Self.hash)","status":"failed","height":null,"failureCode":"INSUFFICIENT_FUNDS"}
            """)
        #expect(response.state == .failed(.insufficientFunds))
    }

    @Test(arguments: [
        #""status":"confirmed""#,                                    // confirmada sem altura
        #""status":"pending","height":10"#,                          // pendente com altura
        #""status":"failed""#,                                       // falha sem código
        #""status":"confirmed","height":10,"failureCode":"MALFORMED""#, // os dois ao mesmo tempo
        #""status":"lost""#,                                         // status desconhecido
    ])
    func combinacaoInvalidaDeEstadoERejeitada(_ fields: String) {
        #expect(throws: DecodingError.self) {
            try decode(TxStatusResponse.self, #"{"hash":"\#(Self.hash)",\#(fields)}"#)
        }
    }

    // MARK: - Demais respostas

    @Test func listaDeTransacoesComPaginacao() throws {
        let list = try decode(TxListResponse.self, """
            {"items":[
              {"hash":"\(Self.hash)","from":"\(Self.addressB)","to":"\(Self.addressA)","amount":300,
               "nonce":3,"status":"confirmed","height":1480,"failureCode":null,"timestamp":1794700000}
            ],"nextBefore":1402}
            """)
        let item = try #require(list.items.first)
        #expect(item.amount == Amount(300))
        #expect(item.from.hex == Self.addressB)
        #expect(item.timestamp == Date(timeIntervalSince1970: 1_794_700_000))
        #expect(list.nextBefore == 1402)
    }

    @Test func ultimaPaginaTemNextBeforeNulo() throws {
        let list = try decode(TxListResponse.self, #"{"items":[],"nextBefore":null}"#)
        #expect(list.items.isEmpty)
        #expect(list.nextBefore == nil)
    }

    @Test func health() throws {
        let health = try decode(HealthResponse.self, #"{"nodeId":"n2","status":"syncing","height":1482}"#)
        #expect(health.status == .syncing)
    }

    // MARK: - Erros

    @Test func erroConhecidoEDecodificadoPeloCodigo() throws {
        let error = try decode(APIError.self, """
            {"error":{"code":"INVALID_NONCE","message":"nonce 4 já usado","details":{"expected":5}}}
            """)
        #expect(error.code == .invalidNonce)
    }

    @Test func erroDesconhecidoEPreservadoSemQuebrar() throws {
        let error = try decode(APIError.self, #"{"error":{"code":"RATE_LIMITED","message":"calma"}}"#)
        #expect(error.code.rawValue == "RATE_LIMITED")
    }

    // MARK: - Envio

    @Test func payloadGeraOsBytesDoContrato() throws {
        let payload = TransferPayload(to: Address(hex: Self.addressA)!, amount: Amount(10), nonce: 4)
        let json = String(decoding: try payload.encodedBytes(), as: UTF8.self)
        #expect(json == #"{"amount":10,"nonce":4,"to":"\#(Self.addressA)","type":"transfer"}"#)
    }

    @Test func envelopeLevaOsBytesExatosEmBase64() throws {
        let payloadBytes = Data(#"{"type":"transfer"}"#.utf8)
        let envelope = TransactionEnvelope(
            payload: payloadBytes, signature: Data([0x30, 0x45]), publicKey: Data([0x30, 0x59]))

        let json = try JSONSerialization.jsonObject(with: APICoding.makeEncoder().encode(envelope)) as? [String: String]
        let payloadDeVolta = try #require(json?["payload"].flatMap { Data(base64Encoded: $0) })

        // Ida e volta: os bytes que chegam ao nó são exatamente os assinados.
        #expect(payloadDeVolta == payloadBytes)
        #expect(json?["signature"] == "MEU=")
        #expect(envelope.hash == TxHash(sha256Of: payloadBytes))
    }
}
