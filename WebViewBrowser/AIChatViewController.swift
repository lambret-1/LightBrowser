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
        titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(renameTapped)))
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
            queryText = kbManager.buildPromptWithKnowledge(text)
        }
        
        var messagesForAPI = messages
        messagesForAPI[streamingMessageIndex] = ChatMessage(role: "user", content: queryText, timestamp: Date().timeIntervalSince1970)
        messagesForAPI.removeLast()
        
        manager.streamChat(messages: messagesForAPI, config: config, model: model, params: params, onToken: { [weak self] token in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.streamingMessageIndex >= 0 && self.streamingMessageIndex < self.messages.count {
                    self.messages[self.streamingMessageIndex].content += token
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: self.streamingMessageIndex, section: 0)) as? AIChatCell {
                        cell.configure(with: self.messages[self.streamingMessageIndex])
                    }
                    self.scrollToBottom()
                }
            }
        }) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isStreaming = false
                self.sendButton.isHidden = false
                self.stopButton.isHidden = true
                if let response = response {
                    self.messages[self.streamingMessageIndex].content = response
                } else if let error = error {
                    self.messages[self.streamingMessageIndex].content = "❌ 请求失败：\(error.localizedDescription)"
                }
                self.streamingMessageIndex = -1
                self.tableView.reloadData()
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
                if self.streamingMessageIndex >= 0 && self.streamingMessageIndex < self.messages.count {
                    self.messages[self.streamingMessageIndex].content += token
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: self.streamingMessageIndex, section: 0)) as? AIChatCell {
                        cell.configure(with: self.messages[self.streamingMessageIndex])
                    }
                    self.scrollToBottom()
                }
            }
        }) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isStreaming = false
                self.sendButton.isHidden = false
                self.stopButton.isHidden = true
                if let response = response {
                    self.messages[self.streamingMessageIndex].content = response
                } else if let error = error {
                    self.messages[self.streamingMessageIndex].content = "❌ 请求失败：\(error.localizedDescription)"
                }
                self.streamingMessageIndex = -1
                self.tableView.reloadData()
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
    
    @objc private func renameTapped() {
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
        actionStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8).isActive = true
        actionStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12).isActive = true
        actionStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8).isActive = true
        actionStack.heightAnchor.constraint(equalToConstant: 24).isActive = true
        roleLabel.bottomAnchor.constraint(equalTo: bubbleView.topAnchor, constant: -2).isActive = true
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
