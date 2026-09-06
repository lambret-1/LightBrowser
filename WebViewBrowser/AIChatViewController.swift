import UIKit

// MARK: - AI 对话页面（全屏）
class AIChatViewController: UIViewController {
    
    // MARK: - UI 元素
    private var tableView: UITableView!
    private var inputContainer: UIView!
    private var inputTextView: UITextView!
    private var sendButton: UIButton!
    private var topBar: UIView!
    private var titleLabel: UILabel!
    private var modelButton: UIButton!
    private var settingsButton: UIButton!
    private var closeButton: UIButton!
    private var bottomConstraint: NSLayoutConstraint!
    
    // MARK: - 数据
    private var messages: [ChatMessage] = []
    private var isLoading = false
    private let manager = AIModelManager.shared
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupKeyboardObservers()
        loadMessages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateModelButton()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI 搭建
    private func setupUI() {
        // 顶部栏
        topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .systemBackground
        topBar.layer.borderWidth = 0.5
        topBar.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(topBar)
        
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "AI 对话"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        
        settingsButton = UIButton(type: .system)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .label
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        topBar.addSubview(settingsButton)
        
        // 模型选择按钮
        modelButton = UIButton(type: .system)
        modelButton.translatesAutoresizingMaskIntoConstraints = false
        modelButton.titleLabel?.font = .systemFont(ofSize: 13)
        modelButton.tintColor = .systemBlue
        modelButton.addTarget(self, action: #selector(modelTapped), for: .touchUpInside)
        topBar.addSubview(modelButton)
        
        // 消息列表
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.register(AIChatCell.self, forCellReuseIdentifier: "AIChatCell")
        tableView.register(AILoadingCell.self, forCellReuseIdentifier: "AILoadingCell")
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.addSubview(tableView)
        
        // 输入区域
        inputContainer = UIView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .systemBackground
        inputContainer.layer.borderWidth = 0.5
        inputContainer.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(inputContainer)
        
        inputTextView = UITextView()
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.font = .systemFont(ofSize: 16)
        inputTextView.delegate = self
        inputTextView.isScrollEnabled = false
        inputTextView.layer.cornerRadius = 18
        inputTextView.layer.borderWidth = 1
        inputTextView.layer.borderColor = UIColor.separator.cgColor
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        inputContainer.addSubview(inputTextView)
        
        sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = .systemBlue
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        inputContainer.addSubview(sendButton)
        
        // 约束
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 52),
            
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            settingsButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            
            modelButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            modelButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
            
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            inputTextView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputTextView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputTextView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputTextView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            inputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            inputTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -12),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: frame.height - self.view.safeAreaInsets.bottom, right: 0)
        }
        scrollToBottom()
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.additionalSafeAreaInsets = .zero
        }
    }
    
    // MARK: - 消息管理
    private func loadMessages() {
        // 加载历史消息（简化版，实际可持久化）
        if messages.isEmpty {
            let welcome = ChatMessage(role: "assistant", content: "你好！我是 AI 助手，有什么可以帮你的吗？\n\n你可以在顶部切换模型，在设置中管理 API 接口。", timestamp: Date().timeIntervalSince1970)
            messages.append(welcome)
        }
        tableView.reloadData()
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        DispatchQueue.main.async {
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    private func updateModelButton() {
        let model = manager.currentModel
        modelButton.setTitle(model, for: .normal)
    }
    
    // MARK: - 发送消息
    @objc private func sendTapped() {
        guard let text = inputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !isLoading else { return }
        
        let userMsg = ChatMessage(role: "user", content: text, timestamp: Date().timeIntervalSince1970)
        messages.append(userMsg)
        inputTextView.text = ""
        textViewDidChange(inputTextView)
        tableView.reloadData()
        scrollToBottom()
        
        isLoading = true
        tableView.reloadData()
        
        guard let config = manager.currentConfig(), !config.apiKey.isEmpty else {
            isLoading = false
            let errorMsg = ChatMessage(role: "assistant", content: "⚠️ 请先在设置中配置 API Key", timestamp: Date().timeIntervalSince1970)
            messages.append(errorMsg)
            tableView.reloadData()
            scrollToBottom()
            return
        }
        
        let params = manager.loadParams()
        let model = manager.currentModel
        
        manager.sendChat(messages: messages, config: config, model: model, params: params) { [weak self] response, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let response = response {
                let aiMsg = ChatMessage(role: "assistant", content: response, timestamp: Date().timeIntervalSince1970)
                self.messages.append(aiMsg)
            } else if let error = error {
                let errorMsg = ChatMessage(role: "assistant", content: "❌ 请求失败：\(error.localizedDescription)", timestamp: Date().timeIntervalSince1970)
                self.messages.append(errorMsg)
            }
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }
    
    // MARK: - 按钮事件
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func settingsTapped() {
        let settingsVC = AISettingsViewController()
        settingsVC.delegate = self
        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    
    @objc private func modelTapped() {
        guard let config = manager.currentConfig() else { return }
        let alert = UIAlertController(title: "选择模型", message: "当前配置：\(config.name)", preferredStyle: .actionSheet)
        
        for model in config.models {
            let isSelected = model == manager.currentModel
            let title = isSelected ? "✓ \(model)" : model
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                AIModelManager.shared.currentModel = model
                self.updateModelButton()
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = modelButton
            popover.sourceRect = modelButton.bounds
        }
        present(alert, animated: true)
    }
    
    // 清空对话
    @objc private func clearChat() {
        let alert = UIAlertController(title: "清空对话", message: "确定要清空所有对话记录吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            self.messages.removeAll()
            self.loadMessages()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension AIChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count + (isLoading ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == messages.count && isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AILoadingCell", for: indexPath) as! AILoadingCell
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "AIChatCell", for: indexPath) as! AIChatCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITextViewDelegate
extension AIChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
        if size.height < 120 {
            textView.isScrollEnabled = false
        } else {
            textView.isScrollEnabled = true
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            sendTapped()
            return false
        }
        return true
    }
}

// MARK: - 设置页面代理
extension AIChatViewController: AISettingsDelegate {
    func didUpdateSettings() {
        updateModelButton()
    }
}

// MARK: - 消息 Cell
class AIChatCell: UITableViewCell {
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let roleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
        
        roleLabel.font = .systemFont(ofSize: 11)
        roleLabel.textColor = .secondaryLabel
        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(roleLabel)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            roleLabel.bottomAnchor.constraint(equalTo: bubbleView.topAnchor, constant: -2),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
        
        let isUser = message.role == "user"
        bubbleView.backgroundColor = isUser ? .systemBlue : .secondarySystemBackground
        messageLabel.textColor = isUser ? .white : .label
        roleLabel.text = isUser ? "我" : "AI"
        
        // 移除旧约束
        bubbleView.constraints.forEach { constraint in
            if constraint.firstAttribute == .leading || constraint.firstAttribute == .trailing {
                constraint.isActive = false
            }
        }
        roleLabel.constraints.forEach { $0.isActive = false }
        
        if isUser {
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12).isActive = true
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
            roleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor).isActive = true
            roleLabel.textAlignment = .right
        } else {
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12).isActive = true
            bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]
            roleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
            roleLabel.textAlignment = .left
        }
    }
}

// MARK: - 加载中 Cell
class AILoadingCell: UITableViewCell {
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let bubbleView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        
        bubbleView.backgroundColor = .secondarySystemBackground
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        bubbleView.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(equalToConstant: 50),
            bubbleView.heightAnchor.constraint(equalToConstant: 40),
            
            indicator.centerXAnchor.constraint(equalTo: bubbleView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 设置页面代理协议
protocol AISettingsDelegate: AnyObject {
    func didUpdateSettings()
}

// MARK: - AI 设置页面
class AISettingsViewController: UIViewController {
    weak var delegate: AISettingsDelegate?
    
    private var tableView: UITableView!
    private var configs: [APIConfig] = []
    private var params: ChatParams!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AI 设置"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        
        configs = AIModelManager.shared.loadConfigs()
        params = AIModelManager.shared.loadParams()
        
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    @objc private func doneTapped() {
        delegate?.didUpdateSettings()
        dismiss(animated: true)
    }
    
    private func reloadData() {
        configs = AIModelManager.shared.loadConfigs()
        tableView.reloadData()
    }
}

extension AISettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return configs.count + 1  // API 配置列表 + 添加
        case 1: return 3                   // 对话参数
        case 2: return 1                   // System Prompt
        case 3: return 1                   // 清空对话
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "API 接口管理"
        case 1: return "对话参数"
        case 2: return "系统提示词"
        case 3: return "其他"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .none
        cell.textLabel?.font = .systemFont(ofSize: 15)
        
        switch indexPath.section {
        case 0:
            if indexPath.row < configs.count {
                let config = configs[indexPath.row]
                cell.textLabel?.text = config.name
                cell.detailTextLabel?.text = config.isDefault ? "默认 · \(config.baseURL)" : config.baseURL
                cell.accessoryType = config.isDefault ? .checkmark : .disclosureIndicator
            } else {
                cell.textLabel?.text = "＋ 添加 API 配置"
                cell.textLabel?.textColor = .systemBlue
            }
        case 1:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Temperature"
                cell.detailTextLabel?.text = String(format: "%.1f", params.temperature)
            case 1:
                cell.textLabel?.text = "Max Tokens"
                cell.detailTextLabel?.text = "\(params.maxTokens)"
            case 2:
                cell.textLabel?.text = "Top P"
                cell.detailTextLabel?.text = String(format: "%.1f", params.topP)
            default: break
            }
            cell.accessoryType = .disclosureIndicator
        case 2:
            cell.textLabel?.text = "系统提示词"
            cell.detailTextLabel?.text = params.systemPrompt
            cell.accessoryType = .disclosureIndicator
        case 3:
            cell.textLabel?.text = "清空对话记录"
            cell.textLabel?.textColor = .systemRed
        default: break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            if indexPath.row < configs.count {
                let config = configs[indexPath.row]
                editConfig(config)
            } else {
                addConfig()
            }
        case 1:
            editParam(at: indexPath.row)
        case 2:
            editSystemPrompt()
        case 3:
            // 清空对话由主页面处理，这里发通知
            NotificationCenter.default.post(name: NSNotification.Name("ClearAIChat"), object: nil)
            showToast("对话已清空")
        default: break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 && indexPath.row < configs.count
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let config = configs[indexPath.row]
            AIModelManager.shared.deleteConfig(config)
            reloadData()
        }
    }
    
    // MARK: - 添加/编辑配置
    private func addConfig() {
        let alert = UIAlertController(title: "选择厂商", message: nil, preferredStyle: .actionSheet)
        for template in AIModelManager.presetTemplates {
            alert.addAction(UIAlertAction(title: template.name, style: .default) { _ in
                self.showConfigEditor(name: template.name, baseURL: template.baseURL, apiKey: "", models: [], isNew: true)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func editConfig(_ config: APIConfig) {
        showConfigEditor(name: config.name, baseURL: config.baseURL, apiKey: config.apiKey, models: config.models, isNew: false, config: config)
    }
    
    private func showConfigEditor(name: String, baseURL: String, apiKey: String, models: [String], isNew: Bool, config: APIConfig? = nil) {
        let alert = UIAlertController(title: isNew ? "添加 API 配置" : "编辑配置", message: nil, preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "配置名称"
            tf.text = name
        }
        alert.addTextField { tf in
            tf.placeholder = "API 地址 (如 https://xxx.com/v1)"
            tf.text = baseURL
        }
        alert.addTextField { tf in
            tf.placeholder = "API Key"
            tf.text = apiKey
            tf.isSecureTextEntry = true
        }
        alert.addTextField { tf in
            tf.placeholder = "模型列表（逗号分隔，留空自动获取）"
            tf.text = models.joined(separator: ",")
        }
        
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let baseURL = alert.textFields?[1].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let apiKey = alert.textFields?[2].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let modelsStr = alert.textFields?[3].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let models = modelsStr.isEmpty ? [] : modelsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            
            if isNew {
                let newConfig = APIConfig(id: UUID().uuidString, name: name, baseURL: baseURL, apiKey: apiKey, models: models, isDefault: self.configs.isEmpty)
                AIModelManager.shared.addConfig(newConfig)
            } else if var config = config {
                config.name = name
                config.baseURL = baseURL
                config.apiKey = apiKey
                config.models = models
                AIModelManager.shared.updateConfig(config)
            }
            self.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "设为默认", style: .default) { _ in
            if var config = config {
                config.isDefault = true
                AIModelManager.shared.updateConfig(config)
                self.reloadData()
            }
        })
        
        alert.addAction(UIAlertAction(title: "获取模型列表", style: .default) { _ in
            guard let config = config else { return }
            AIModelManager.shared.fetchModels(for: config) { models, error in
                if let models = models {
                    var updated = config
                    updated.models = models
                    AIModelManager.shared.updateConfig(updated)
                    self.reloadData()
                    self.showToast("已获取 \(models.count) 个模型")
                } else {
                    self.showToast("获取失败：\(error?.localizedDescription ?? "未知错误")")
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - 编辑参数
    private func editParam(at row: Int) {
        let titles = ["Temperature", "Max Tokens", "Top P"]
        let currentValues: [String] = [
            String(format: "%.1f", params.temperature),
            "\(params.maxTokens)",
            String(format: "%.1f", params.topP)
        ]
        
        let alert = UIAlertController(title: titles[row], message: "范围：\(row == 0 ? "0.0 - 2.0" : row == 1 ? "1 - 32768" : "0.0 - 1.0")", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = currentValues[row]
            tf.keyboardType = .decimalPad
        }
        
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            let value = alert.textFields?[0].text ?? ""
            switch row {
            case 0:
                if let v = Double(value) { self.params.temperature = max(0, min(2, v)) }
            case 1:
                if let v = Int(value) { self.params.maxTokens = max(1, min(32768, v)) }
            case 2:
                if let v = Double(value) { self.params.topP = max(0, min(1, v)) }
            default: break
            }
            AIModelManager.shared.saveParams(self.params)
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func editSystemPrompt() {
        let alert = UIAlertController(title: "系统提示词", message: "设置 AI 的角色和行为", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = self.params.systemPrompt
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            self.params.systemPrompt = alert.textFields?[0].text ?? ""
            AIModelManager.shared.saveParams(self.params)
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showToast(_ message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(toast, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            toast.dismiss(animated: true)
        }
    }
}
