import Testing
import UIKit
import Foundation
@testable import Coincoin

@MainActor
struct AppComposerTests {

    @Test func tabBarTemExatamenteCarteiraEHistorico() {
        let root = AppComposer().makeTabs(signer: InMemorySigner())

        #expect(root.tabs.map(\.identifier) == [AppComposer.TabID.wallet, AppComposer.TabID.activity])
        #expect(root.tabs.map(\.title) == ["Carteira", "Histórico"])
    }
    
    @Test func semCarteiraPossivelAbreAsBoasVindasDeDemonstracao() {
        let loader = WalletLoader(
            store: KeychainStore(service: "personalproject.Coincoin.tests", account: UUID().uuidString),
            canHoldKey: { false })

        let root = AppComposer(loader: loader).makeRootViewController()

        #expect(root is OnboardingViewController)
    }

    
    @Test func coresDoDesignSystemExistemNoCatalogo() {
        let bundle = Bundle(for: SceneDelegate.self)
        let nomes = ["AccentColor", "OnAccent", "AccentSoft", "OnAccentSoft", "Background", "Surface", "Divider"]

        for nome in nomes {
            #expect(UIColor(named: nome, in: bundle, compatibleWith: nil) != nil, "Color Set ausente: \(nome)")
        }
    }
}
