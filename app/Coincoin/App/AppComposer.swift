import UIKit

/// Raiz de composição: o único lugar que escolhe implementações concretas e as injeta.
struct AppComposer {

    enum TabID {
        static let wallet = "wallet"
        static let activity = "activity"
    }

    let loader: WalletLoader

    init(loader: WalletLoader = WalletLoader()) {
        self.loader = loader
    }

    func makeRootViewController() -> UIViewController {
        let state = loader.load()
        if case .ready(let signer) = state {
            return makeTabs(signer: signer)
        }
        guard let viewModel = OnboardingViewModel(state: state, loader: loader) else {
            return UIViewController()
        }
        return OnboardingViewController(viewModel: viewModel, makeNext: makeTabs)
    }

    func makeTabs(signer: any TransactionSigner) -> UITabBarController {
        let demo = DemoEnvironment.make(wallet: signer.address)
        let node: any NodeClient = demo.node
        let wallet = signer.address
        let tracker = TransactionTracker(node: demo.node, signer: signer)
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
