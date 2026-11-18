//
//  PaymentRequestTests.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Coincoin

struct PaymentRequestTests {

    static let hex = "a3f901bc77e2" + String(repeating: "0", count: 24) + "7c21"
    static let address = Address(hex: hex)!

    // MARK: - Formato

    @Test func uriSoComOEndereco() {
        #expect(PaymentRequest(address: Self.address).uri == "coincoin:\(Self.hex)")
    }

    @Test func uriComValor() {
        #expect(PaymentRequest(address: Self.address, amount: Amount(50)).uri == "coincoin:\(Self.hex)?amount=50")
    }

    // MARK: - Leitura

    @Test(arguments: [
        "coincoin:\(hex)",
        "COINCOIN:\(hex.uppercased())",
        "  coincoin:\(hex)\n",
        hex,
        hex.uppercased(),
        "coincoin:\(hex)?label=Loja",
    ])
    func leEnderecoValido(_ text: String) {
        let request = PaymentRequest(scanned: text)
        #expect(request == PaymentRequest(address: Self.address))
    }

    @Test func leValor() {
        #expect(PaymentRequest(scanned: "coincoin:\(Self.hex)?amount=50")?.amount == Amount(50))
    }

    @Test(arguments: [
        "bitcoin:\(hex)",
        "coincoin:a3f9",
        "coincoin:\(hex)?amount=0",
        "coincoin:\(hex)?amount=-5",
        "coincoin:\(hex)?amount=1.5",
        "coincoin:\(hex)?amount=18446744073709551616",
        "coincoin:\(hex)?amount=10&amount=20",
        "coincoin:\(hex)?req-memo=x",
        "https://exemplo.com",
        "",
    ])
    func recusaConteudoInvalido(_ text: String) {
        #expect(PaymentRequest(scanned: text) == nil)
    }

    @Test func idaEVolta() {
        let original = PaymentRequest(address: Self.address, amount: Amount(1_250))
        #expect(PaymentRequest(scanned: original.uri) == original)
    }

    // MARK: - QR

    @Test func qrCodeGeradoEDecodificadoDevolveAMesmaURI() throws {
        let uri = PaymentRequest(address: Self.address).uri
        let image = try #require(QRCode.image(for: uri, side: 220, scale: 3)?.cgImage)

        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let features = detector.features(in: CIImage(cgImage: image)).compactMap { $0 as? CIQRCodeFeature }

        #expect(features.map(\.messageString) == [uri])
    }
}
