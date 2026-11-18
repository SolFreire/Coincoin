//
//  SendViewModelTests.swift
//  Coincoin
//
//  Created by Soraia Freire Batista on 18/11/26.
//

import Foundation
import Testing
@testable import Coincoin

@MainActor
struct SendViewModelTests {

    static let bob = Address(hex: String(repeating: "b0", count: 20))!

    func make(
        balance: UInt64 = 100,
        available: UInt64 = 100,
        signer: any TransactionSigner = InMemorySigner()
    ) -> (MockNodeClient, SendViewModel) {
        let node = MockNodeClient(balances: [signer.address: Amount(balance)])
        let tracker = TransactionTracker(node: node, signer: signer)
        return (node, SendViewModel(tracker: tracker, wallet: signer.address, available: Amount(available)))
    }

    // MARK: - Endereço

    @Test func camposVaziosNaoMostramErroMasNaoEnviam() {
        let (_, viewModel) = make()

        #expect(viewModel.addressIssue == nil)
        #expect(viewModel.amountIssue == nil)
        #expect(viewModel.canSend == false)
    }

    @Test(arguments: [
        String(repeating: "B0", count: 20),
        String(repeating: "b0b0 ", count: 10),
        " " + String(repeating: "b0", count: 20) + "\n",
    ])
    func enderecoNormalizado(_ text: String) {
        let (_, viewModel) = make()
        viewModel.addressText = text
        #expect(viewModel.addressIssue == nil)
    }

    @Test func enderecoInvalido() {
        let (_, viewModel) = make()
        viewModel.addressText = "b0b0"
        #expect(viewModel.addressIssue == .invalid)
    }

    @Test func proprioEndereco() {
        let signer = InMemorySigner()
        let (_, viewModel) = make(signer: signer)
        viewModel.addressText = signer.address.hex
        #expect(viewModel.addressIssue == .ownAddress)
    }

    // MARK: - Valor

    @Test(arguments: [
        ("12a", SendViewModel.AmountIssue.notANumber),
        ("-5", .notANumber),
        ("١٢", .notANumber),
        ("0", .zero),
        ("101", .exceedsAvailable),
        ("18446744073709551616", .exceedsAvailable),
    ])
    func valorRecusado(_ text: String, _ issue: SendViewModel.AmountIssue) {
        let (_, viewModel) = make(available: 100)
        viewModel.amountText = text
        #expect(viewModel.amountIssue == issue)
    }

    @Test func exatamenteODisponivelPode() {
        let (_, viewModel) = make(available: 100)
        viewModel.addressText = Self.bob.hex
        viewModel.amountText = "100"
        #expect(viewModel.amountIssue == nil)
        #expect(viewModel.canSend)
    }

    // MARK: - Envio

    @Test func envioAceitoTerminaComoEnviado() async {
        let (_, viewModel) = make()
        viewModel.addressText = Self.bob.hex
        viewModel.amountText = "30"

        await viewModel.send()

        guard case .sent(let transaction) = viewModel.status else {
            Issue.record("Esperava .sent, veio \(viewModel.status)")
            return
        }
        #expect(transaction.phase == .pending)
    }

    @Test func respostaPerdidaTambemTerminaComoEnviadoEConferindo() async {
        let (node, viewModel) = make()
        await node.failNextSubmits(.dropResponse)
        viewModel.addressText = Self.bob.hex
        viewModel.amountText = "30"

        await viewModel.send()

        guard case .sent(let transaction) = viewModel.status else {
            Issue.record("Resposta perdida não pode virar falha: veio \(viewModel.status)")
            return
        }
        #expect(transaction.phase == .unknown)
    }

    @Test func noRecusaMesmoQuandoATelaAceitaEEditarLimpaOErro() async {
        let (_, viewModel) = make(balance: 5, available: 100)
        viewModel.addressText = Self.bob.hex
        viewModel.amountText = "30"

        await viewModel.send()
        #expect(viewModel.status == .failed(.rejected(APIError(code: .insufficientFunds, message: "Saldo insuficiente"))))

        viewModel.amountText = "3"
        #expect(viewModel.status == .editing)
    }

    @Test func faceIDCanceladoVoltaAEditarSemErro() async {
        let (_, viewModel) = make(signer: CancellingSigner())
        viewModel.addressText = Self.bob.hex
        viewModel.amountText = "30"

        await viewModel.send()

        #expect(viewModel.status == .editing)
    }

    @Test func toqueDuploEnviaUmaVezSo() async {
        let (_, viewModel) = make()
        viewModel.addressText = Self.bob.hex
        viewModel.amountText = "30"

        async let first: Void = viewModel.send()
        async let second: Void = viewModel.send()
        _ = await (first, second)

        guard case .sent(let transaction) = viewModel.status else {
            Issue.record("Esperava .sent, veio \(viewModel.status)")
            return
        }
        #expect(transaction.transfer.nonce == 0)
    }
}
