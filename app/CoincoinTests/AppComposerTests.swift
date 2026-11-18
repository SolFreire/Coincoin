import Testing
import UIKit
@testable import Coincoin

@MainActor
struct AppComposerTests {

    @Test func tabBarTemExatamenteCarteiraEHistorico() {
        let root = AppComposer(signer: InMemorySigner()).makeRootViewController()

        #expect(root.tabs.map(\.identifier) == [AppComposer.TabID.wallet, AppComposer.TabID.activity])
        #expect(root.tabs.map(\.title) == ["Carteira", "Histórico"])
    }

    @Test func coresDoDesignSystemExistemNoCatalogo() {
        let bundle = Bundle(for: SceneDelegate.self)
        let nomes = ["AccentColor", "OnAccent", "AccentSoft", "OnAccentSoft", "Background", "Surface", "Divider"]

        for nome in nomes {
            #expect(UIColor(named: nome, in: bundle, compatibleWith: nil) != nil, "Color Set ausente: \(nome)")
        }
    }
}
