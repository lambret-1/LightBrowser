import UIKit

/// 设置中心页面（5大分组 + 搜索）
class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar()
    
    // 设置项数据结构
    private struct SettingItem {
        let title: String
        let subtitle: String?
        let type: ItemType
        let key: String?
        let options: [String]?
        let action: (() -> Void)?
        
        enum ItemType {
            case switchToggle
            case selection
            case slider
            case navigation
            case button
        }
    }
    
    private struct SettingSection {
        let title: String
        let footer: String?
        var items: [SettingItem]
    }
    
    private var sections: [SettingSection] = []
    private var filteredSections: [SettingSection] = []
    private var isSearching = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        buildSections()
    }
    
    private func setupUI() {
        // 导航栏返回按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeVC)
        )
        
        // 搜索栏
        searchBar.placeholder = "搜索设置项"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        navigationItem.titleView = searchBar
        
        // 表格
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 52
        tableView.sectionHeaderHeight = 40
        tableView.register(SettingSwitchCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(SettingSelectionCell.self, forCellReuseIdentifier: "selectionCell")
        tableView.register(SettingSliderCell.self, forCellReuseIdentifier: "sliderCell")
        tableView.register(SettingNavigationCell.self, forCellReuseIdentifier: "navCell")
        tableView.register(SettingButtonCell.self, forCellReuseIdentifier: "buttonCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func closeVC() {
        dismiss(animated: true)
    }
    
    // MARK: - 构建设置项
    private func buildSections() {
        let sm = SettingsManager.shared
        
        sections = [
            // 通用
            SettingSection(title: "通用", footer: "调整浏览器基础行为", items: [
                SettingItem(title: "地址栏位置", subtitle: sm.addressBarPosition == "top" ? "顶部" : "底部", type: .selection, key: "addressBar", options: ["顶部", "底部"], action: nil),
                SettingItem(title: "默认搜索引擎", subtitle: sm.defaultSearchEngine == "baidu" ? "百度" : "谷歌", type: .selection, key: "searchEngine", options: ["百度", "谷歌"], action: nil),
                SettingItem(title: "User Agent", subtitle: uaDisplayName(sm.userAgent), type: .selection, key: "userAgent", options: ["iPhone", "iPad", "Windows", "Mac"], action: nil),
                SettingItem(title: "手势灵敏度", subtitle: String(format: "%.1f", sm.gestureSensitivity), type: .slider, key: "gesture", options: nil, action: nil),
                SettingItem(title: "菜单弹出速度", subtitle: String(format: "%.1fs", sm.menuAnimationDuration), type: .slider, key: "menuSpeed", options: nil, action: nil)
            ]),
            // 隐私与拦截
            SettingSection(title: "隐私与拦截", footer: "广告拦截与隐私保护", items: [
                SettingItem(title: "广告拦截", subtitle: nil, type: .switchToggle, key: "adBlock", options: nil, action: nil),
                SettingItem(title: "全局图片拦截", subtitle: "拦截所有网页图片", type: .switchToggle, key: "imageBlock", options: nil, action: nil),
                SettingItem(title: "广告黑名单管理", subtitle: "自定义拦截域名", type: .navigation, key: nil, options: nil, action: { [weak self] in
                    self?.showAdBlockManager()
                }),
                SettingItem(title: "缓存管理", subtitle: "查看和清理缓存", type: .navigation, key: nil, options: nil, action: { [weak self] in
                    self?.showCacheManager()
                })
            ]),
            // 性能
            SettingSection(title: "性能", footer: "优化加载速度与电量消耗", items: [
                SettingItem(title: "DNS 预解析", subtitle: "提前解析常用域名", type: .switchToggle, key: "dnsPrefetch", options: nil, action: nil),
                SettingItem(title: "禁止媒体自动播放", subtitle: nil, type: .switchToggle, key: "mediaAutoplay", options: nil, action: nil),
                SettingItem(title: "后台动画节流", subtitle: "后台标签暂停动画", type: .switchToggle, key: "bgThrottle", options: nil, action: nil),
                SettingItem(title: "内存告警自动清理", subtitle: nil, type: .switchToggle, key: "memoryClear", options: nil, action: nil),
                SettingItem(title: "性能日志", subtitle: "查看启动与加载耗时", type: .navigation, key: nil, options: nil, action: { [weak self] in
                    self?.showDebugLog()
                })
            ]),
            // 高级
            SettingSection(title: "高级", footer: "调试与配置管理", items: [
                SettingItem(title: "调试日志", subtitle: "崩溃与运行日志", type: .navigation, key: nil, options: nil, action: { [weak self] in
                    self?.showDebugLog()
                }),
                SettingItem(title: "代理/VLESS 配置", subtitle: nil, type: .navigation, key: nil, options: nil, action: { [weak self] in
                    self?.showProxySettings()
                }),
                SettingItem(title: "导出配置", subtitle: "备份所有设置为JSON", type: .button, key: nil, options: nil, action: { [weak self] in
                    self?.exportConfig()
                }),
                SettingItem(title: "导入配置", subtitle: "从JSON恢复设置", type: .button, key: nil, options: nil, action: { [weak self] in
                    self?.importConfig()
                }),
                SettingItem(title: "重置全部设置", subtitle: nil, type: .button, key: nil, options: nil, action: { [weak self] in
                    self?.resetAllSettings()
                })
            ]),
            // 关于
            SettingSection(title: "关于", footer: nil, items: [
                SettingItem(title: "当前版本", subtitle: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知", type: .navigation, key: nil, options: nil, action: nil),
                SettingItem(title: "启动时自动检测更新", subtitle: nil, type: .switchToggle, key: "autoCheckUpdate", options: nil, action: nil),
                SettingItem(title: "检查更新", subtitle: "对比GitHub最新版本", type: .button, key: nil, options: nil, action: { [weak self] in
                    self?.checkUpdate()
                }),
                SettingItem(title: "GitHub 仓库", subtitle: "lambret-1/LightBrowser", type: .navigation, key: nil, options: nil, action: {
                    if let url = URL(string: "https://github.com/lambret-1/LightBrowser") {
                        UIApplication.shared.open(url)
                    }
                })
            ])
        ]
        filteredSections = sections
    }
    
    private func uaDisplayName(_ ua: String) -> String {
        switch ua {
        case "iphone": return "iPhone"
        case "ipad": return "iPad"
        case "windows": return "Windows PC"
        case "mac": return "Mac"
        default: return ua
        }
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? filteredSections.count : sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let s = isSearching ? filteredSections[section] : sections[section]
        return s.items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let s = isSearching ? filteredSections[section] : sections[section]
        return s.title
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let s = isSearching ? filteredSections[section] : sections[section]
        return s.footer
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let s = isSearching ? filteredSections[indexPath.section] : sections[indexPath.section]
        let item = s.items[indexPath.row]
        
        switch item.type {
        case .switchToggle:
            let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as! SettingSwitchCell
            cell.configure(title: item.title, isOn: boolValue(for: item.key ?? ""))
            cell.onToggle = { [weak self] isOn in
                self?.setBoolValue(isOn, for: item.key ?? "")
            }
            return cell
        case .selection:
            let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath) as! SettingSelectionCell
            cell.configure(title: item.title, value: item.subtitle ?? "")
            return cell
        case .slider:
            let cell = tableView.dequeueReusableCell(withIdentifier: "sliderCell", for: indexPath) as! SettingSliderCell
            cell.configure(title: item.title, value: sliderValue(for: item.key ?? ""), key: item.key ?? "")
            cell.onValueChanged = { [weak self] val in
                self?.setSliderValue(val, for: item.key ?? "")
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
        case .navigation:
            let cell = tableView.dequeueReusableCell(withIdentifier: "navCell", for: indexPath) as! SettingNavigationCell
            cell.configure(title: item.title, subtitle: item.subtitle)
            return cell
        case .button:
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell", for: indexPath) as! SettingButtonCell
            cell.configure(title: item.title, isDestructive: item.title == "重置全部设置")
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = isSearching ? filteredSections[indexPath.section] : sections[indexPath.section]
        let item = s.items[indexPath.row]
        
        if item.type == .selection, let options = item.options {
            showSelectionAlert(title: item.title, options: options, key: item.key ?? "")
        } else if let action = item.action {
            action()
        }
    }
    
    // MARK: - 设置值读写
    private func boolValue(for key: String) -> Bool {
        let sm = SettingsManager.shared
        switch key {
        case "adBlock": return sm.adBlockEnabled
        case "imageBlock": return sm.globalImageBlock
        case "dnsPrefetch": return sm.dnsPrefetchEnabled
        case "mediaAutoplay": return sm.mediaAutoplayBlocked
        case "bgThrottle": return sm.backgroundAnimationThrottle
        case "memoryClear": return sm.memoryWarningAutoClear
        case "autoCheckUpdate": return sm.autoCheckUpdate
        default: return false
        }
    }
    
    private func setBoolValue(_ value: Bool, for key: String) {
        let sm = SettingsManager.shared
        switch key {
        case "adBlock": sm.adBlockEnabled = value
        case "imageBlock": sm.globalImageBlock = value
        case "dnsPrefetch": sm.dnsPrefetchEnabled = value
        case "mediaAutoplay": sm.mediaAutoplayBlocked = value
        case "bgThrottle": sm.backgroundAnimationThrottle = value
        case "memoryClear": sm.memoryWarningAutoClear = value
        case "autoCheckUpdate": sm.autoCheckUpdate = value
        default: break
        }
    }
    
    private func sliderValue(for key: String) -> Float {
        let sm = SettingsManager.shared
        switch key {
        case "gesture": return Float(sm.gestureSensitivity)
        case "menuSpeed": return Float(sm.menuAnimationDuration)
        default: return 0.5
        }
    }
    
    private func setSliderValue(_ value: Float, for key: String) {
        let sm = SettingsManager.shared
        switch key {
        case "gesture": sm.gestureSensitivity = Double(value)
        case "menuSpeed": sm.menuAnimationDuration = Double(value)
        default: break
        }
    }
    
    // MARK: - 选择弹窗
    private func showSelectionAlert(title: String, options: [String], key: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            alert.addAction(UIAlertAction(title: option, style: .default) { [weak self] _ in
                self?.applySelection(option: option, key: key)
                self?.buildSections()
                self?.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }
    
    private func applySelection(option: String, key: String) {
        let sm = SettingsManager.shared
        switch key {
        case "addressBar":
            sm.addressBarPosition = option == "顶部" ? "top" : "bottom"
        case "searchEngine":
            sm.defaultSearchEngine = option == "百度" ? "baidu" : "google"
        case "userAgent":
            let map = ["iPhone": "iphone", "iPad": "ipad", "Windows": "windows", "Mac": "mac"]
            sm.userAgent = map[option] ?? "iphone"
        default: break
        }
    }
    
    // MARK: - 子页面跳转
    private func showAdBlockManager() {
        // 跳转广告黑名单管理（复用现有功能）
        showToast("广告黑名单管理")
    }
    
    private func showCacheManager() {
        let cacheVC = CacheManagerViewController()
        navigationController?.pushViewController(cacheVC, animated: true)
    }
    
    private func showDebugLog() {
        let debugVC = DebugLogViewController()
        navigationController?.pushViewController(debugVC, animated: true)
    }
    
    private func showProxySettings() {
        showToast("代理/VLESS 配置")
    }
    
    // MARK: - 配置导入导出
    private func exportConfig() {
        let json = SettingsManager.shared.exportSettings()
        let activityVC = UIActivityViewController(activityItems: [json], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
    }
    
    private func importConfig() {
        let alert = UIAlertController(title: "导入配置", message: "粘贴JSON配置字符串", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "粘贴配置JSON"
        }
        alert.addAction(UIAlertAction(title: "导入", style: .default) { [weak self] _ in
            if let json = alert.textFields?.first?.text,
               SettingsManager.shared.importSettings(from: json) {
                self?.showToast("配置导入成功")
                self?.buildSections()
                self?.tableView.reloadData()
            } else {
                self?.showToast("配置格式错误")
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func resetAllSettings() {
        let alert = UIAlertController(title: "重置全部设置", message: "确定要重置所有设置为默认值吗？此操作不可撤销。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            SettingsManager.shared.resetAllSettings()
            self?.showToast("已重置全部设置")
            self?.buildSections()
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }
    
    // MARK: - 检查更新
    private func checkUpdate() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        showToast("正在检查更新...")
        SettingsManager.shared.checkForUpdate(repo: "lambret-1/LightBrowser", currentVersion: current) { hasUpdate, latest in
            if hasUpdate, let latest = latest {
                let alert = UIAlertController(title: "发现新版本", message: "最新版本：v\(latest)\n当前版本：v\(current)\n\n下载后请用 TrollStore 安装更新", preferredStyle: .alert)
                // 直接下载 IPA
                alert.addAction(UIAlertAction(title: "下载更新", style: .default) { _ in
                    let ipaURL = "https://github.com/lambret-1/LightBrowser/releases/download/v\(latest)/LightBrowser-v\(latest).ipa"
                    if let url = URL(string: ipaURL) {
                        UIApplication.shared.open(url)
                    }
                })
                // 前往 Release 页面
                alert.addAction(UIAlertAction(title: "查看详情", style: .default) { _ in
                    if let url = URL(string: "https://github.com/lambret-1/LightBrowser/releases") {
                        UIApplication.shared.open(url)
                    }
                })
                alert.addAction(UIAlertAction(title: "稍后", style: .cancel))
                self.present(alert, animated: true)
            } else {
                self.showToast("已是最新版本")
            }
        }
    }
    
    // MARK: - 搜索
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredSections = sections
        } else {
            isSearching = true
            filteredSections = sections.map { section in
                var s = section
                s.items = s.items.filter { item in
                    item.title.localizedCaseInsensitiveContains(searchText) ||
                    (item.subtitle ?? "").localizedCaseInsensitiveContains(searchText)
                }
                return s
            }.filter { !$0.items.isEmpty }
        }
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    // MARK: - Toast
    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = .systemFont(ofSize: 14)
        toast.layer.cornerRadius = 10
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 250),
            toast.heightAnchor.constraint(equalToConstant: 40)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.3) { toast.alpha = 0 } completion: { _ in toast.removeFromSuperview() }
        }
    }
}

// MARK: - 自定义 Cell
class SettingSwitchCell: UITableViewCell {
    let toggle = UISwitch()
    var onToggle: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        accessoryView = toggle
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(title: String, isOn: Bool) {
        textLabel?.text = title
        textLabel?.font = .systemFont(ofSize: 16)
        toggle.isOn = isOn
    }
    
    @objc private func toggled() { onToggle?(toggle.isOn) }
}

class SettingSelectionCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(title: String, value: String) {
        textLabel?.text = title
        textLabel?.font = .systemFont(ofSize: 16)
        detailTextLabel?.text = value
        detailTextLabel?.textColor = .secondaryLabel
    }
}

class SettingSliderCell: UITableViewCell {
    let slider = UISlider()
    let valueLabel = UILabel()
    var onValueChanged: ((Float) -> Void)?
    private var key = ""
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        
        slider.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        
        contentView.addSubview(slider)
        contentView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slider.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            slider.widthAnchor.constraint(equalToConstant: 180),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(title: String, value: Float, key: String) {
        textLabel?.text = title
        textLabel?.font = .systemFont(ofSize: 16)
        self.key = key
        if key == "gesture" {
            slider.minimumValue = 0.3
            slider.maximumValue = 0.7
        } else {
            slider.minimumValue = 0.2
            slider.maximumValue = 1.0
        }
        slider.value = value
        updateValueLabel()
    }
    
    @objc private func sliderChanged() {
        updateValueLabel()
        onValueChanged?(slider.value)
    }
    
    private func updateValueLabel() {
        if key == "menuSpeed" {
            valueLabel.text = String(format: "%.1fs", slider.value)
        } else {
            valueLabel.text = String(format: "%.1f", slider.value)
        }
    }
}

class SettingNavigationCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(title: String, subtitle: String?) {
        textLabel?.text = title
        textLabel?.font = .systemFont(ofSize: 16)
        detailTextLabel?.text = subtitle
        detailTextLabel?.textColor = .secondaryLabel
    }
}

class SettingButtonCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(title: String, isDestructive: Bool) {
        textLabel?.text = title
        textLabel?.font = .systemFont(ofSize: 16)
        textLabel?.textAlignment = .center
        textLabel?.textColor = isDestructive ? .systemRed : .systemBlue
    }
}
