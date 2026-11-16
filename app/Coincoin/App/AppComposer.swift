import UIKit

/// Raiz de composição: o único lugar que escolhe implementações concretas e as injeta.
struct AppComposer {

    enum TabID {
        static let wallet = "wallet"
        static let activity = "activity"
    }

    let node: any NodeClient
    let wallet: Address

    init(node: any NodeClient, wallet: Address) {
        self.node = node
        self.wallet = wallet
    }

    // TODO(passo 9/10): carteira vinda do onboarding e HTTPNodeClient no lugar da demonstração.
    init() {
        let demo = DemoEnvironment.make()
        self.init(node: demo.node, wallet: demo.wallet)
    }

    func makeRootViewController() -> UITabBarController {
        let node = node
        let wallet = wallet
        let tabBarController = UITabBarController()
        tabBarController.tabs = [
            makeTab(id: TabID.wallet, title: String(localized: "Carteira"), symbol: "wallet.bifold") {
                WalletViewController(viewModel: WalletViewModel(node: node, wallet: wallet))
            },
            makeTab(id: TabID.activity, title: String(localized: "Histórico"), symbol: "clock.arrow.circlepath") {
                ActivityViewController()
            },
        ]
        return tabBarController
    }

    /// `root` só é chamado quando a aba é aberta pela primeira vez.
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
