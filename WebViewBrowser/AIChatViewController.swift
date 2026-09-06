import UIKit

// MARK: - AI 对话页面（全屏增强版）
class AIChatViewController: UIViewController {
    
    // MARK: - UI 元素
    private var topBar: UIView!
    private var menuButton: UIButton!
    private var titleLabel: UILabel!
    private var modelButton: UIButton!
    private var settingsButton: UIButton!
    private var newChatButton: UIButton!
    
    private var tableView: UITableView!
    private var inputContainer: UIView!
    private var inputTextView: UITextView!
    private var sendButton: UIButton!
    private var stopButton: UIButton!
    private var voiceButton: UIButton!
    private var attachButton: UIButton!
    
    private var sideMenuView: UIView!
    private var sideMenuOverlay: UIButton!
    private var sideMenuLeading: NSLayoutConstraint!
    private var sideMenuTableView: UITableView!
    
    // MARK: - 数据
    private var currentConversation: Conversation?
    private var messages: [ChatMessage] = []
    private var isStreaming = false
    private var streamingMessageIndex = -1
    private var expandedThinkingIndices = Set<Int>()
    private let manager = AIModelManager.shared
    private let convManager = ConversationManager.shared
    private let voiceService = VoiceService.shared
    private let kbManager = KnowledgeBaseManager.shared
    
    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupSideMenu()
        setupKeyboardObservers()
        setupNotifications()
        loadOrCreateConversation()
        manager.loadTokenStats()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateModelButton()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        manager.stopStreaming()
    }
    
    // MARK: - UI 搭建
    private func setupUI() {
        topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .systemBackground
        topBar.layer.borderWidth = 0.5
        topBar.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(topBar)
        
        menuButton = UIButton(type: .system)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        menuButton.tintColor = .label
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        topBar.addSubview(menuButton)
        
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "新对话"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(roleTapped)))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(renameTapped))
        longPress.minimumPressDuration = 0.6
        titleLabel.addGestureRecognizer(longPress)
        topBar.addSubview(titleLabel)
        
        modelButton = UIButton(type: .system)
        modelButton.translatesAutoresizingMaskIntoConstraints = false
        modelButton.titleLabel?.font = .systemFont(ofSize: 12)
        modelButton.tintColor = .systemBlue
        modelButton.addTarget(self, action: #selector(modelTapped), for: .touchUpInside)
        topBar.addSubview(modelButton)
        
        settingsButton = UIButton(type: .system)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .label
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        topBar.addSubview(settingsButton)
        
        newChatButton = UIButton(type: .system)
        newChatButton.translatesAutoresizingMaskIntoConstraints = false
        newChatButton.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        newChatButton.tintColor = .label
        newChatButton.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        topBar.addSubview(newChatButton)
        
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
        
        inputContainer = UIView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .systemBackground
        inputContainer.layer.borderWidth = 0.5
        inputContainer.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(inputContainer)
        
        voiceButton = UIButton(type: .system)
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.setImage(UIImage(systemName: "mic"), for: .normal)
        voiceButton.tintColor = .label
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        inputContainer.addSubview(voiceButton)
        
        attachButton = UIButton(type: .system)
        attachButton.translatesAutoresizingMaskIntoConstraints = false
        attachButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
        attachButton.tintColor = .label
        attachButton.addTarget(self, action: #selector(attachTapped), for: .touchUpInside)
        inputContainer.addSubview(attachButton)
        
        inputTextView = UITextView()
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.font = .systemFont(ofSize: 15)
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
        
        stopButton = UIButton(type: .system)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
        stopButton.tintColor = .systemRed
        stopButton.isHidden = true
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        inputContainer.addSubview(stopButton)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 52),
            
            menuButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            menuButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 32),
            menuButton.heightAnchor.constraint(equalToConstant: 32),
            
            newChatButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            newChatButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            newChatButton.widthAnchor.constraint(equalToConstant: 32),
            newChatButton.heightAnchor.constraint(equalToConstant: 32),
            
            settingsButton.trailingAnchor.constraint(equalTo: newChatButton.leadingAnchor, constant: -8),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            
            modelButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            modelButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: menuButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: modelButton.leadingAnchor, constant: -8),
            
            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
            
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            voiceButton.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 8),
            voiceButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -12),
            voiceButton.widthAnchor.constraint(equalToConstant: 32),
            voiceButton.heightAnchor.constraint(equalToConstant: 32),
            
            attachButton.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 4),
            attachButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -12),
            attachButton.widthAnchor.constraint(equalToConstant: 32),
            attachButton.heightAnchor.constraint(equalToConstant: 32),
            
            inputTextView.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 8),
            inputTextView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputTextView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputTextView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            inputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            inputTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -12),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            
            stopButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            stopButton.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -12),
            stopButton.widthAnchor.constraint(equalToConstant: 36),
            stopButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    
    private func setupSideMenu() {
        sideMenuOverlay = UIButton(type: .system)
        sideMenuOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        sideMenuOverlay.alpha = 0
        sideMenuOverlay.isHidden = true
        sideMenuOverlay.addTarget(self, action: #selector(closeSideMenu), for: .touchUpInside)
        sideMenuOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sideMenuOverlay)
        
        sideMenuView = UIView()
        sideMenuView.backgroundColor = .systemBackground
        sideMenuView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sideMenuView)
        
        sideMenuLeading = sideMenuView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -280)
        
        let sideTitle = UILabel()
        sideTitle.text = "历史对话"
        sideTitle.font = .systemFont(ofSize: 18, weight: .bold)
        sideTitle.translatesAutoresizingMaskIntoConstraints = false
        sideMenuView.addSubview(sideTitle)
        
        sideMenuTableView = UITableView()
        sideMenuTableView.translatesAutoresizingMaskIntoConstraints = false
        sideMenuTableView.delegate = self
        sideMenuTableView.dataSource = self
        sideMenuTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ConvCell")
        sideMenuView.addSubview(sideMenuTableView)
        
        NSLayoutConstraint.activate([
            sideMenuOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            sideMenuOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sideMenuOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sideMenuOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            sideMenuLeading,
            sideMenuView.topAnchor.constraint(equalTo: view.topAnchor),
            sideMenuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sideMenuView.widthAnchor.constraint(equalToConstant: 280),
            
            sideTitle.topAnchor.constraint(equalTo: sideMenuView.safeAreaLayoutGuide.topAnchor, constant: 20),
            sideTitle.leadingAnchor.constraint(equalTo: sideMenuView.leadingAnchor, constant: 20),
            
            sideMenuTableView.topAnchor.constraint(equalTo: sideTitle.bottomAnchor, constant: 16),
            sideMenuTableView.leadingAnchor.constraint(equalTo: sideMenuView.leadingAnchor),
            sideMenuTableView.trailingAnchor.constraint(equalTo: sideMenuView.trailingAnchor),
            sideMenuTableView.bottomAnchor.constraint(equalTo: sideMenuView.bottomAnchor),
        ])
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTranslateSelection(_:)), name: NSNotification.Name("AITranslateSelection"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleExplainSelection(_:)), name: NSNotification.Name("AIExplainSelection"), object: nil)
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
    
    private func loadOrCreateConversation() {
        if let conv = convManager.currentConversation() {
            currentConversation = conv
            messages = conv.messages
            titleLabel.text = conv.title
        } else {
            let conv = convManager.createConversation()
            currentConversation = conv
            messages = []
            titleLabel.text = conv.title
            let welcome = ChatMessage(role: "assistant", content: "你好！我是 AI 助手，有什么可以帮你的吗？\n\n支持：流式输出、Markdown渲染、代码高亮、语音输入、知识库问答、划词AI等。", timestamp: Date().timeIntervalSince1970)
            messages.append(welcome)
            saveConversation()
        }
        tableView.reloadData()
    }
    
    private func saveConversation() {
        guard var conv = currentConversation else { return }
        conv.messages = messages
        conv.title = titleLabel.text ?? "新对话"
        convManager.updateConversation(conv)
        currentConversation = conv
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
    
    @objc private func sendTapped() {
        guard let text = inputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !isStreaming else { return }
        
        let userMsg = ChatMessage(role: "user", content: text, timestamp: Date().timeIntervalSince1970)
        messages.append(userMsg)
        inputTextView.text = ""
        textViewDidChange(inputTextView)
        tableView.reloadData()
        scrollToBottom()
        
        if messages.filter({ $0.role == "user" }).count == 1 {
            titleLabel.text = convManager.generateTitle(for: messages)
        }
        
        let aiMsg = ChatMessage(role: "assistant", content: "", timestamp: Date().timeIntervalSince1970)
        messages.append(aiMsg)
        streamingMessageIndex = messages.count - 1
        isStreaming = true
        sendButton.isHidden = true
        stopButton.isHidden = false
        tableView.reloadData()
        
        guard let config = manager.currentConfig(), !config.apiKey.isEmpty else {
            isStreaming = false
            messages[streamingMessageIndex].content = "⚠️ 请先在设置中配置 API Key"
            sendButton.isHidden = false
            stopButton.isHidden = true
            tableView.reloadData()
            saveConversation()
            return
        }
        
        let params = manager.loadParams()
        let model = manager.currentModel
        var queryText = text
        if kbManager.totalDocuments > 0 {
            queryText = kbManager.buildPromptWithKnowledge(query: text)
        }
        
        var messagesForAPI = messages
        messagesForAPI[streamingMessageIndex] = ChatMessage(role: "user", content: queryText, timestamp: Date().timeIntervalSince1970)
        messagesForAPI.removeLast()
        
        manager.streamChat(messages: messagesForAPI, config: config, model: model, params: params, onToken: { [weak self] token in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.streamingMessageIndex >= 0 && self.streamingMessageIndex < self.messages.count else { return }
                self.messages[self.streamingMessageIndex].content += token
                if let cell = self.tableView.cellForRow(at: IndexPath(row: self.streamingMessageIndex, section: 0)) as? AIChatCell {
                    cell.updateStreamingText(self.messages[self.streamingMessageIndex].content)
                }
                if self.tableView.contentOffset.y + self.tableView.frame.height > self.tableView.contentSize.height - 200 {
                    self.tableView.scrollToRow(at: IndexPath(row: self.streamingMessageIndex, section: 0), at: .bottom, animated: false)
                }
            }
        }) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isStreaming = false
                self.sendButton.isHidden = false
                self.stopButton.isHidden = true
                let idx = self.streamingMessageIndex
                if idx >= 0 && idx < self.messages.count {
                    if let response = response {
                        // 解析思考过程
                        let parsed = AIModelManager.parseThinking(from: response)
                        self.messages[idx].content = parsed.content
                        self.messages[idx].thinkingContent = parsed.thinking.isEmpty ? nil : parsed.thinking
                    } else if let error = error {
                        self.messages[idx].content = "❌ 请求失败：\(error.localizedDescription)"
                    }
                    // 只刷新单行，避免长文本全量reloadData导致闪退
                    self.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
                }
                self.streamingMessageIndex = -1
                self.saveConversation()
                self.manager.recordTokens(self.messages.reduce(0) { $0 + $1.content.count / 4 })
            }
        }
    }
    
    @objc private func stopTapped() {
        manager.stopStreaming()
        isStreaming = false
        sendButton.isHidden = false
        stopButton.isHidden = true
        if streamingMessageIndex >= 0 && streamingMessageIndex < messages.count {
            if messages[streamingMessageIndex].content.isEmpty {
                messages[streamingMessageIndex].content = "（已停止生成）"
            }
        }
        streamingMessageIndex = -1
        tableView.reloadData()
        saveConversation()
    }
    
    private func regenerateLastMessage() {
        guard !isStreaming else { return }
        guard let lastAIIndex = messages.lastIndex(where: { $0.role == "assistant" }) else { return }
        guard lastAIIndex > 0 else { return }
        
        messages[lastAIIndex].content = ""
        streamingMessageIndex = lastAIIndex
        isStreaming = true
        sendButton.isHidden = true
        stopButton.isHidden = false
        tableView.reloadData()
        
        guard let config = manager.currentConfig(), !config.apiKey.isEmpty else {
            isStreaming = false
            messages[lastAIIndex].content = "⚠️ 请先配置 API Key"
            sendButton.isHidden = false
            stopButton.isHidden = true
            tableView.reloadData()
            return
        }
        
        let params = manager.loadParams()
        let model = manager.currentModel
        let messagesForAPI = Array(messages.prefix(upTo: lastAIIndex))
        
        manager.streamChat(messages: messagesForAPI, config: config, model: model, params: params, onToken: { [weak self] token in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.streamingMessageIndex >= 0 && self.streamingMessageIndex < self.messages.count else { return }
                self.messages[self.streamingMessageIndex].content += token
                if let cell = self.tableView.cellForRow(at: IndexPath(row: self.streamingMessageIndex, section: 0)) as? AIChatCell {
                    cell.updateStreamingText(self.messages[self.streamingMessageIndex].content)
                }
                if self.tableView.contentOffset.y + self.tableView.frame.height > self.tableView.contentSize.height - 200 {
                    self.tableView.scrollToRow(at: IndexPath(row: self.streamingMessageIndex, section: 0), at: .bottom, animated: false)
                }
            }
        }) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isStreaming = false
                self.sendButton.isHidden = false
                self.stopButton.isHidden = true
                let idx = self.streamingMessageIndex
                if idx >= 0 && idx < self.messages.count {
                    if let response = response {
                        let parsed = AIModelManager.parseThinking(from: response)
                        self.messages[idx].content = parsed.content
                        self.messages[idx].thinkingContent = parsed.thinking.isEmpty ? nil : parsed.thinking
                    } else if let error = error {
                        self.messages[idx].content = "❌ 请求失败：\(error.localizedDescription)"
                    }
                    self.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
                }
                self.streamingMessageIndex = -1
                self.saveConversation()
            }
        }
    }
    
    @objc private func menuTapped() {
        sideMenuTableView.reloadData()
        openSideMenu()
    }
    
    @objc private func newChatTapped() {
        saveConversation()
        let conv = convManager.createConversation()
        currentConversation = conv
        messages = []
        titleLabel.text = conv.title
        let welcome = ChatMessage(role: "assistant", content: "新对话已创建，有什么可以帮你的？", timestamp: Date().timeIntervalSince1970)
        messages.append(welcome)
        saveConversation()
        tableView.reloadData()
        closeSideMenu()
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
        let alert = UIAlertController(title: "选择模型", message: "当前配置：\(config.name)\nToken消耗：\(manager.totalTokensUsed)", preferredStyle: .actionSheet)
        for model in config.models {
            let isSelected = model == manager.currentModel
            let title = isSelected ? "✓ \(model)" : model
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                AIModelManager.shared.currentModel = model
                self.updateModelButton()
            })
        }
        alert.addAction(UIAlertAction(title: "重置Token统计", style: .destructive) { _ in
            self.manager.resetTokenStats()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = modelButton
        }
        present(alert, animated: true)
    }
    
    @objc private func roleTapped() {
        let alert = UIAlertController(title: "选择角色", message: "当前：\(manager.currentRole.name)", preferredStyle: .actionSheet)
        for role in AIRole.presets {
            let isSelected = role.name == manager.currentRole.name
            let title = isSelected ? "✓ \(role.name)" : role.name
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                self.manager.currentRole = role
                if !role.prompt.isEmpty {
                    var params = self.manager.loadParams()
                    params.systemPrompt = role.prompt
                    self.manager.saveParams(params)
                }
                self.showToast("已切换角色：\(role.name)")
            })
        }
        alert.addAction(UIAlertAction(title: "自定义提示词", style: .default) { _ in
            let params = self.manager.loadParams()
            let subAlert = UIAlertController(title: "自定义系统提示词", message: nil, preferredStyle: .alert)
            subAlert.addTextField { $0.text = params.systemPrompt }
            subAlert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
                var p = self.manager.loadParams()
                p.systemPrompt = subAlert.textFields?[0].text ?? ""
                self.manager.saveParams(p)
                self.manager.currentRole = AIRole(name: "自定义", prompt: p.systemPrompt, icon: "slider.horizontal.3")
                self.showToast("自定义角色已保存")
            })
            subAlert.addAction(UIAlertAction(title: "取消", style: .cancel))
            self.present(subAlert, animated: true)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = titleLabel
        }
        present(alert, animated: true)
    }
    
    @objc private func renameTapped(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let alert = UIAlertController(title: "重命名对话", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = self.titleLabel.text }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            self.titleLabel.text = alert.textFields?[0].text ?? "新对话"
            self.saveConversation()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func voiceTapped() {
        if voiceService.isRecording {
            voiceService.stopRecording()
            voiceButton.tintColor = .label
            voiceButton.setImage(UIImage(systemName: "mic"), for: .normal)
        } else {
            voiceService.requestAuthorization { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.voiceService.startRecording { text, error in
                        if let text = text {
                            DispatchQueue.main.async {
                                self.inputTextView.text = text
                            }
                        }
                    }
                    self.voiceButton.tintColor = .systemRed
                    self.voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
                } else {
                    self.showToast("请在设置中允许语音识别权限")
                }
            }
        }
    }
    
    @objc private func attachTapped() {
        let alert = UIAlertController(title: "添加附件", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "📄 上传到知识库", style: .default) { _ in
            self.showKnowledgeBase()
        })
        alert.addAction(UIAlertAction(title: "📋 粘贴文本", style: .default) { _ in
            if let text = UIPasteboard.general.string {
                self.inputTextView.text = (self.inputTextView.text ?? "") + "\n" + text
            }
        })
        alert.addAction(UIAlertAction(title: "🔊 朗读最后回复", style: .default) { _ in
            if let lastAI = self.messages.last(where: { $0.role == "assistant" }) {
                self.voiceService.speak(lastAI.content)
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = attachButton
        }
        present(alert, animated: true)
    }
    
    private func showKnowledgeBase() {
        let alert = UIAlertController(title: "知识库", message: "当前文档数：\(kbManager.totalDocuments)\n总大小：\(kbManager.totalSize)字符", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "输入文档名称" }
        alert.addTextField { $0.placeholder = "粘贴文档内容" }
        alert.addAction(UIAlertAction(title: "添加文档", style: .default) { _ in
            let name = alert.textFields?[0].text ?? "未命名"
            let content = alert.textFields?[1].text ?? ""
            if !content.isEmpty {
                _ = self.kbManager.addDocument(name: name, content: content, fileType: "txt")
                self.showToast("文档已添加到知识库")
            }
        })
        alert.addAction(UIAlertAction(title: "清空知识库", style: .destructive) { _ in
            for doc in self.kbManager.loadDocuments() {
                self.kbManager.deleteDocument(doc)
            }
            self.showToast("知识库已清空")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func openSideMenu() {
        sideMenuOverlay.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.sideMenuLeading.constant = 0
            self.sideMenuOverlay.alpha = 1
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func closeSideMenu() {
        UIView.animate(withDuration: 0.3, animations: {
            self.sideMenuLeading.constant = -280
            self.sideMenuOverlay.alpha = 0
            self.view.layoutIfNeeded()
        }) { _ in
            self.sideMenuOverlay.isHidden = true
        }
    }
    
    @objc private func handleTranslateSelection(_ notification: Notification) {
        guard let text = notification.object as? String else { return }
        dismiss(animated: true) {
            let userMsg = ChatMessage(role: "user", content: "请翻译以下内容为中文：\n\(text)", timestamp: Date().timeIntervalSince1970)
            self.messages.append(userMsg)
            self.sendTapped()
        }
    }
    
    @objc private func handleExplainSelection(_ notification: Notification) {
        guard let text = notification.object as? String else { return }
        dismiss(animated: true) {
            let userMsg = ChatMessage(role: "user", content: "请解释以下内容：\n\(text)", timestamp: Date().timeIntervalSince1970)
            self.messages.append(userMsg)
            self.sendTapped()
        }
    }
    
    private func showToast(_ message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(toast, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            toast.dismiss(animated: true)
        }
    }
}

extension AIChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == sideMenuTableView {
            return convManager.loadConversations().count
        }
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == sideMenuTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConvCell", for: indexPath)
            let convs = convManager.loadConversations()
            let conv = convs[indexPath.row]
            cell.textLabel?.text = conv.title
            cell.textLabel?.numberOfLines = 2
            cell.textLabel?.font = .systemFont(ofSize: 14)
            cell.accessoryType = conv.id == currentConversation?.id ? .checkmark : .none
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "AIChatCell", for: indexPath) as! AIChatCell
        cell.isThinkingExpanded = expandedThinkingIndices.contains(indexPath.row)
        cell.configure(with: messages[indexPath.row])
        cell.delegate = self
        cell.messageIndex = indexPath.row
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == sideMenuTableView { return 60 }
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == sideMenuTableView { return 60 }
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == sideMenuTableView {
            let convs = convManager.loadConversations()
            let conv = convs[indexPath.row]
            saveConversation()
            currentConversation = conv
            messages = conv.messages
            titleLabel.text = conv.title
            convManager.currentConversationID = conv.id
            tableView.reloadData()
            self.tableView.reloadData()
            closeSideMenu()
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if tableView == sideMenuTableView {
            let convs = convManager.loadConversations()
            let conv = convs[indexPath.row]
            let delete = UIContextualAction(style: .destructive, title: "删除") { _, _, completion in
                self.convManager.deleteConversation(conv)
                self.sideMenuTableView.reloadData()
                completion(true)
            }
            let pin = UIContextualAction(style: .normal, title: conv.isPinned ? "取消置顶" : "置顶") { _, _, completion in
                self.convManager.togglePin(conv)
                self.sideMenuTableView.reloadData()
                completion(true)
            }
            pin.backgroundColor = .systemOrange
            return UISwipeActionsConfiguration(actions: [delete, pin])
        }
        return nil
    }
}

protocol AIChatCellDelegate: AnyObject {
    func didTapCopy(at index: Int)
    func didTapRegenerate(at index: Int)
    func didTapDelete(at index: Int)
    func didTapSpeak(at index: Int)
    func didToggleThinking(at index: Int)
}

extension AIChatViewController: AIChatCellDelegate {
    func didTapCopy(at index: Int) {
        guard index < messages.count else { return }
        UIPasteboard.general.string = messages[index].content
        showToast("已复制")
    }
    func didTapRegenerate(at index: Int) { regenerateLastMessage() }
    func didTapDelete(at index: Int) {
        guard index < messages.count else { return }
        messages.remove(at: index)
        tableView.reloadData()
        saveConversation()
    }
    func didTapSpeak(at index: Int) {
        guard index < messages.count else { return }
        voiceService.speak(messages[index].content)
    }
    func didToggleThinking(at index: Int) {
        guard index < messages.count else { return }
        if expandedThinkingIndices.contains(index) {
            expandedThinkingIndices.remove(index)
        } else {
            expandedThinkingIndices.insert(index)
        }
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }
}

extension AIChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
        textView.isScrollEnabled = size.height >= 120
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            sendTapped()
            return false
        }
        return true
    }
}

extension AIChatViewController: AISettingsDelegate {
    func didUpdateSettings() { updateModelButton() }
}

class AIChatCell: UITableViewCell {
    weak var delegate: AIChatCellDelegate?
    var messageIndex = -1
    
    private let bubbleView = UIView()
    private let messageLabel = UITextView()
    private let roleLabel = UILabel()
    private let actionStack = UIStackView()
    private let copyButton = UIButton(type: .system)
    private let regenerateButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let speakButton = UIButton(type: .system)
    
    // 思考过程折叠
    private let thinkingContainer = UIView()
    private let thinkingButton = UIButton(type: .system)
    private let thinkingTextView = UITextView()
    private var isThinkingExpanded = false
    private var thinkingHeightConstraint: NSLayoutConstraint?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        messageLabel.isEditable = false
        messageLabel.isScrollEnabled = false
        messageLabel.backgroundColor = .clear
        messageLabel.textContainerInset = .zero
        messageLabel.textContainer.lineFragmentPadding = 0
        messageLabel.dataDetectorTypes = .link
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
        
        roleLabel.font = .systemFont(ofSize: 11)
        roleLabel.textColor = .secondaryLabel
        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(roleLabel)
        
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .secondaryLabel
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        regenerateButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        regenerateButton.tintColor = .secondaryLabel
        regenerateButton.addTarget(self, action: #selector(regenerateTapped), for: .touchUpInside)
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .secondaryLabel
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        speakButton.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        speakButton.tintColor = .secondaryLabel
        speakButton.addTarget(self, action: #selector(speakTapped), for: .touchUpInside)
        
        actionStack.axis = .horizontal
        actionStack.spacing = 12
        actionStack.distribution = .fillEqually
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.addArrangedSubview(copyButton)
        actionStack.addArrangedSubview(regenerateButton)
        actionStack.addArrangedSubview(speakButton)
        actionStack.addArrangedSubview(deleteButton)
        bubbleView.addSubview(actionStack)
        
        // 思考过程折叠区域
        thinkingContainer.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.5)
        thinkingContainer.layer.cornerRadius = 8
        thinkingContainer.translatesAutoresizingMaskIntoConstraints = false
        thinkingContainer.isHidden = true
        bubbleView.addSubview(thinkingContainer)
        
        thinkingButton.setTitle("💭 思考过程", for: .normal)
        thinkingButton.titleLabel?.font = .systemFont(ofSize: 12)
        thinkingButton.tintColor = .secondaryLabel
        thinkingButton.contentHorizontalAlignment = .left
        thinkingButton.translatesAutoresizingMaskIntoConstraints = false
        thinkingButton.addTarget(self, action: #selector(toggleThinking), for: .touchUpInside)
        thinkingContainer.addSubview(thinkingButton)
        
        thinkingTextView.isEditable = false
        thinkingTextView.isScrollEnabled = false
        thinkingTextView.backgroundColor = .clear
        thinkingTextView.font = .systemFont(ofSize: 12)
        thinkingTextView.textColor = .secondaryLabel
        thinkingTextView.textContainerInset = .zero
        thinkingTextView.textContainer.lineFragmentPadding = 0
        thinkingTextView.translatesAutoresizingMaskIntoConstraints = false
        thinkingTextView.isHidden = true
        thinkingContainer.addSubview(thinkingTextView)
        
        NSLayoutConstraint.activate([
            thinkingButton.topAnchor.constraint(equalTo: thinkingContainer.topAnchor, constant: 6),
            thinkingButton.leadingAnchor.constraint(equalTo: thinkingContainer.leadingAnchor, constant: 10),
            thinkingButton.trailingAnchor.constraint(equalTo: thinkingContainer.trailingAnchor, constant: -10),
            thinkingButton.heightAnchor.constraint(equalToConstant: 20),
            thinkingTextView.topAnchor.constraint(equalTo: thinkingButton.bottomAnchor, constant: 4),
            thinkingTextView.leadingAnchor.constraint(equalTo: thinkingContainer.leadingAnchor, constant: 10),
            thinkingTextView.trailingAnchor.constraint(equalTo: thinkingContainer.trailingAnchor, constant: -10),
            thinkingTextView.bottomAnchor.constraint(equalTo: thinkingContainer.bottomAnchor, constant: -6),
        ])
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85),
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            actionStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            actionStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            actionStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            actionStack.heightAnchor.constraint(equalToConstant: 24),
            roleLabel.bottomAnchor.constraint(equalTo: bubbleView.topAnchor, constant: -2),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with message: ChatMessage) {
        let attributed = MarkdownRenderer.render(message.content, fontSize: 15)
        messageLabel.attributedText = attributed
        
        let isUser = message.role == "user"
        bubbleView.backgroundColor = isUser ? .systemBlue : .secondarySystemBackground
        roleLabel.text = isUser ? "我" : "AI"
        actionStack.isHidden = isUser
        
        // 思考过程
        if let thinking = message.thinkingContent, !thinking.isEmpty, !isUser {
            thinkingContainer.isHidden = false
            thinkingTextView.text = thinking
            thinkingButton.setTitle(isThinkingExpanded ? "💭 思考过程 ▲" : "💭 思考过程 ▼", for: .normal)
            thinkingTextView.isHidden = !isThinkingExpanded
        } else {
            thinkingContainer.isHidden = true
            thinkingTextView.isHidden = true
        }
        
        bubbleView.constraints.forEach { $0.isActive = false }
        roleLabel.constraints.forEach { $0.isActive = false }
        
        if isUser {
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12).isActive = true
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
            roleLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor).isActive = true
            roleLabel.textAlignment = .right
            messageLabel.textColor = .white
        } else {
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12).isActive = true
            bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]
            roleLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
            roleLabel.textAlignment = .left
            messageLabel.textColor = .label
        }
        
        messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10).isActive = true
        messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12).isActive = true
        messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12).isActive = true
        
        // 思考过程在消息正文下方
        if !thinkingContainer.isHidden {
            thinkingContainer.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8).isActive = true
            thinkingContainer.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8).isActive = true
            thinkingContainer.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8).isActive = true
            actionStack.topAnchor.constraint(equalTo: thinkingContainer.bottomAnchor, constant: 8).isActive = true
        } else {
            actionStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8).isActive = true
        }
        
        actionStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12).isActive = true
        actionStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8).isActive = true
        actionStack.heightAnchor.constraint(equalToConstant: 24).isActive = true
        roleLabel.bottomAnchor.constraint(equalTo: bubbleView.topAnchor, constant: -2).isActive = true
    }
    
    @objc private func toggleThinking() {
        isThinkingExpanded.toggle()
        thinkingTextView.isHidden = !isThinkingExpanded
        thinkingButton.setTitle(isThinkingExpanded ? "💭 思考过程 ▲" : "💭 思考过程 ▼", for: .normal)
        delegate?.didToggleThinking(at: messageIndex)
    }
    
    /// 流式输出时直接更新纯文本，不重新渲染 Markdown，避免高频重建约束导致崩溃
    func updateStreamingText(_ text: String) {
        messageLabel.attributedText = nil
        messageLabel.text = text
        messageLabel.font = .systemFont(ofSize: 15)
    }
    
    @objc private func copyTapped() { delegate?.didTapCopy(at: messageIndex) }
    @objc private func regenerateTapped() { delegate?.didTapRegenerate(at: messageIndex) }
    @objc private func deleteTapped() { delegate?.didTapDelete(at: messageIndex) }
    @objc private func speakTapped() { delegate?.didTapSpeak(at: messageIndex) }
}

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
    
    private func showToast(_ message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(toast, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast.dismiss(animated: true) }
    }
}

extension AISettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { return 4 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return configs.count + 1
        case 1: return 3
        case 2: return 1
        case 3: return 1
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
                editConfig(configs[indexPath.row])
            } else {
                addConfig()
            }
        case 1:
            editParam(at: indexPath.row)
        case 2:
            editSystemPrompt()
        case 3:
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
            AIModelManager.shared.deleteConfig(configs[indexPath.row])
            reloadData()
        }
    }
    
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
        alert.addTextField { $0.placeholder = "配置名称"; $0.text = name }
        alert.addTextField { $0.placeholder = "API 地址"; $0.text = baseURL }
        alert.addTextField { $0.placeholder = "API Key"; $0.text = apiKey; $0.isSecureTextEntry = true }
        alert.addTextField { $0.placeholder = "模型列表（逗号分隔，留空自动获取）"; $0.text = models.joined(separator: ",") }
        
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
        
        if let config = config {
            alert.addAction(UIAlertAction(title: "设为默认", style: .default) { _ in
                var updated = config
                updated.isDefault = true
                AIModelManager.shared.updateConfig(updated)
                self.reloadData()
            })
            alert.addAction(UIAlertAction(title: "获取模型列表", style: .default) { _ in
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
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func editParam(at row: Int) {
        let titles = ["Temperature", "Max Tokens", "Top P"]
        let currentValues = [String(format: "%.1f", params.temperature), "\(params.maxTokens)", String(format: "%.1f", params.topP)]
        let alert = UIAlertController(title: titles[row], message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = currentValues[row]; $0.keyboardType = .decimalPad }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            let value = alert.textFields?[0].text ?? ""
            switch row {
            case 0: if let v = Double(value) { self.params.temperature = max(0, min(2, v)) }
            case 1: if let v = Int(value) { self.params.maxTokens = max(1, min(32768, v)) }
            case 2: if let v = Double(value) { self.params.topP = max(0, min(1, v)) }
            default: break
            }
            AIModelManager.shared.saveParams(self.params)
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func editSystemPrompt() {
        let alert = UIAlertController(title: "系统提示词", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = self.params.systemPrompt }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            self.params.systemPrompt = alert.textFields?[0].text ?? ""
            AIModelManager.shared.saveParams(self.params)
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}
