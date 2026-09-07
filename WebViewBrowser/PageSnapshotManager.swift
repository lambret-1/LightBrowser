import UIKit

/// Safari式网页快照管理器
/// 保存每个标签的URL、滚动位置、页面截图，APP重启后先显示截图再后台加载
class PageSnapshotManager {
    static let shared = PageSnapshotManager()
    
    private let fileManager = FileManager.default
    private var snapshotDir: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("PageSnapshots", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// 快照数据结构
    struct SnapshotData: Codable {
        let url: String
        let scrollY: CGFloat
        let timestamp: TimeInterval
    }
    
    private init() {}
    
    /// 保存标签快照
    func saveSnapshot(index: Int, url: String, scrollY: CGFloat, image: UIImage?) {
        // 保存元数据
        let data = SnapshotData(url: url, scrollY: scrollY, timestamp: Date().timeIntervalSince1970)
        if let encoded = try? JSONEncoder().encode(data) {
            let metaURL = snapshotDir.appendingPathComponent("snapshot_\(index).json")
            try? encoded.write(to: metaURL)
        }
        // 保存截图
        if let image = image, let pngData = image.pngData() {
            let imgURL = snapshotDir.appendingPathComponent("snapshot_\(index).png")
            try? pngData.write(to: imgURL)
        }
    }
    
    /// 读取标签快照元数据
    func getSnapshot(index: Int) -> SnapshotData? {
        let metaURL = snapshotDir.appendingPathComponent("snapshot_\(index).json")
        guard let data = try? Data(contentsOf: metaURL),
              let snapshot = try? JSONDecoder().decode(SnapshotData.self, from: data) else {
            return nil
        }
        return snapshot
    }
    
    /// 读取标签快照截图
    func getSnapshotImage(index: Int) -> UIImage? {
        let imgURL = snapshotDir.appendingPathComponent("snapshot_\(index).png")
        guard let data = try? Data(contentsOf: imgURL) else { return nil }
        return UIImage(data: data)
    }
    
    /// 删除标签快照
    func deleteSnapshot(index: Int) {
        let metaURL = snapshotDir.appendingPathComponent("snapshot_\(index).json")
        let imgURL = snapshotDir.appendingPathComponent("snapshot_\(index).png")
        try? fileManager.removeItem(at: metaURL)
        try? fileManager.removeItem(at: imgURL)
    }
    
    /// 清除所有快照
    func clearAllSnapshots() {
        try? fileManager.removeItem(at: snapshotDir)
    }
    
    /// 是否启用快照恢复功能
    var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "snapshotRestoreEnabled")
    }
    
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "snapshotRestoreEnabled")
    }
}
