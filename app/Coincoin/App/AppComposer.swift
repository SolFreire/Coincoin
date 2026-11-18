import UIKit

/// Raiz de composição: o único lugar que escolhe implementações concretas e as injeta.
struct AppComposer {

    enum TabID {
        static let wallet = "wallet"
        static let activity = "activity"
    }

    let node: any NodeClient
    let wallet: Address
    let tracker: TransactionTracker

    init(signer: any TransactionSigner) {
        let demo = DemoEnvironment.make(wallet: signer.address)
        node = demo.node
        wallet = signer.address
        tracker = TransactionTracker(node: demo.node, signer: signer)
    }

    init() {
        self.init(signer: DemoEnvironment.makeWalletSigner())
    }

    func makeRootViewController() -> UITabBarController {
        let node = node
        let wallet = wallet
        let tracker = tracker
        let tabBarController = UITabBarController()
        tabBarController.tabs = [
            makeTab(id: TabID.wallet, title: String(localized: "Carteira"), symbol: "wallet.bifold") {
                WalletViewController(viewModel: WalletViewModel(node: node, tracker: tracker, wallet: wallet))
            },
            
            makeTab(id: TabID.activity, title: String(localized: "Histórico"), symbol: "clock.arrow.circlepath") {
                ActivityViewController(viewModel: ActivityViewModel(node: node, wallet: wallet))
            },
        ]
        return tabBarController
    }

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
