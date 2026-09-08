import UIKit
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        // 包一层导航控制器：缓存管理页使用 push 打开，系统原生边缘右滑返回（无黑屏）
        let navController = UINavigationController(rootViewController: ViewController())
        navController.setNavigationBarHidden(true, animated: false)
        window.rootViewController = navController
        window.makeKeyAndVisible()
        self.window = window
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        DebugLogger.shared.logInfo("通过URL Scheme打开: \(url.absoluteString)")
        // 处理 lightbrowser://open?url=xxx
        if url.scheme == "lightbrowser", let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let targetURLString = queryItems.first(where: { $0.name == "url" })?.value,
           let targetURL = URL(string: targetURLString) {
            if let navController = window?.rootViewController as? UINavigationController,
               let viewController = navController.viewControllers.first as? ViewController {
                viewController.openURLFromExternal(targetURL)
            }
        }
    }
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {
        // APP切后台前保存网页快照
        if let navController = window?.rootViewController as? UINavigationController,
           let viewController = navController.viewControllers.first as? ViewController {
            viewController.saveAllSnapshots()
        }
    }
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {
        // APP进入后台时再次确保保存快照
        if let navController = window?.rootViewController as? UINavigationController,
           let viewController = navController.viewControllers.first as? ViewController {
            viewController.saveAllSnapshots()
        }
    }
}
