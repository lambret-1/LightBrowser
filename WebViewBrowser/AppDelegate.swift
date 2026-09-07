import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化全局调试日志（自动捕获崩溃）
        _ = DebugLogger.shared
        DebugLogger.shared.logInfo("应用启动")
        // 四级分层缓存：内存→瞬时磁盘(30min)→持久静态(7天)→网络兜底
        let cache = FourLevelCache(memoryCapacity: 80 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, diskPath: "FourLevelCache")
        URLCache.shared = cache
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
