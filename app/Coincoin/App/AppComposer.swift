import UIKit

/// Raiz de composição: o único lugar do app que decide quais implementações concretas
/// são usadas e como as telas são montadas.
///
/// Hoje só monta a tab bar. Nos próximos passos, é aqui que se escolhe `MockNodeClient`
/// ou `HTTPNodeClient`, `KeychainSigner` ou `SecureEnclaveSigner`, e se injetam essas
/// dependências nos view models. As telas nunca criam as próprias dependências.
struct AppComposer {

    /// Identificadores estáveis das abas, usados também nos testes.
    enum TabID {
        static let wallet = "wallet"
        static let activity = "activity"
    }

    func makeRootViewController() -> UITabBarController {
        let tabBarController = UITabBarController()
        tabBarController.tabs = [
            makeTab(
                id: TabID.wallet,
                title: String(localized: "Carteira"),
                symbol: "wallet.bifold",
                root: WalletViewController.init
            ),
            makeTab(
                id: TabID.activity,
                title: String(localized: "Histórico"),
                symbol: "clock.arrow.circlepath",
                root: ActivityViewController.init
            ),
        ]
        return tabBarController
    }

    /// Cada aba tem a própria pilha de navegação, com título grande (padrão da HIG).
    /// `root` é uma fábrica: a tela só é criada quando a aba é aberta pela primeira vez.
    private func makeTab(
        id: String,
        title: String,
        symbol: String,
        root: @escaping () -> UIViewController
    ) -> UITab {
        UITab(title: title, image: UIImage(systemName: symbol), identifier: id) { _ in
            let rootViewController = root()
            rootViewController.title = title
            let navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.navigationBar.prefersLargeTitles = true
            return navigationController
        }
    }
}
