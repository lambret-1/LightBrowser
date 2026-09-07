import UIKit

/// 底部查找栏（iOS14-15 JS兜底方案使用，iOS16+用系统原生查找栏）
/// 支持键盘跟随：键盘弹出时查找栏自动上移到键盘顶部
class FindBarView: UIView {
    // MARK: - 回调
    var onSearch: ((String) -> Void)?
    var onNext: (() -> Void)?
    var onPrev: (() -> Void)?
    var onClose: (() -> Void)?
    
    // MARK: - UI元素
    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "查找网页内容"
        tf.font = .systemFont(ofSize: 15)
        tf.borderStyle = .roundedRect
        tf.backgroundColor = .secondarySystemBackground
        tf.returnKeyType = .search
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        return tf
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "0/0"
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private let prevButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        btn.tintColor = .systemBlue
        btn.setContentHuggingPriority(.required, for: .horizontal)
        return btn
    }()
    
    private let nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        btn.tintColor = .systemBlue
        btn.setContentHuggingPriority(.required, for: .horizontal)
        return btn
    }()
    
    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = .secondaryLabel
        btn.setContentHuggingPriority(.required, for: .horizontal)
        return btn
    }()
    
    private var bottomConstraint: NSLayoutConstraint!
    private var isVisible = false
    private weak var hostView: UIView?
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
        setupKeyboardObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.15
        
        let stackView = UIStackView(arrangedSubviews: [searchTextField, countLabel, prevButton, nextButton, closeButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
            stackView.heightAnchor.constraint(equalToConstant: 36),
            
            prevButton.widthAnchor.constraint(equalToConstant: 32),
            nextButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            countLabel.widthAnchor.constraint(equalToConstant: 50),
        ])
    }
    
    private func setupActions() {
        searchTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        searchTextField.delegate = self
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }
    
    // MARK: - 键盘监听
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard isVisible, let hostView = hostView else { return }
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        // 转换键盘frame到hostView坐标系
        let keyboardFrameInView = hostView.convert(keyboardFrame, from: nil)
        let keyboardTop = hostView.bounds.height - keyboardFrameInView.origin.y
        
        // 更新底部约束到键盘顶部
        bottomConstraint.constant = -keyboardTop
        
        UIView.animate(withDuration: duration) {
            hostView.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard isVisible, let hostView = hostView else { return }
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        // 恢复到底部安全区
        bottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            hostView.layoutIfNeeded()
        }
    }
    
    // MARK: - 公共方法
    
    /// 显示查找栏
    func show(in view: UIView, initialText: String = "") {
        guard !isVisible else {
            searchTextField.text = initialText
            if !initialText.isEmpty {
                onSearch?(initialText)
            }
            return
        }
        
        hostView = view
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        
        // 底部约束（初始在屏幕外下方）
        bottomConstraint = bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 100)
        
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightAnchor.constraint(equalToConstant: 52),
            bottomConstraint,
        ])
        
        view.layoutIfNeeded()
        
        searchTextField.text = initialText
        isVisible = true
        
        // 动画滑入
        UIView.animate(withDuration: 0.25, animations: {
            self.bottomConstraint.constant = 0
            view.layoutIfNeeded()
        }) { _ in
            self.searchTextField.becomeFirstResponder()
            if !initialText.isEmpty {
                self.onSearch?(initialText)
            }
        }
    }
    
    /// 隐藏查找栏
    func hide() {
        guard isVisible else { return }
        isVisible = false
        searchTextField.resignFirstResponder()
        
        UIView.animate(withDuration: 0.25, animations: {
            self.bottomConstraint.constant = 100
            self.hostView?.layoutIfNeeded()
        }) { _ in
            self.removeFromSuperview()
            self.hostView = nil
        }
    }
    
    /// 更新匹配计数
    func updateCount(current: Int, total: Int) {
        countLabel.text = "\(current)/\(total)"
        countLabel.textColor = total == 0 ? .systemRed : .secondaryLabel
    }
    
    /// 设置关键词
    func setKeyword(_ keyword: String) {
        searchTextField.text = keyword
    }
    
    // MARK: - 动作
    @objc private func textFieldDidChange() {
        // 防抖300ms
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
        perform(#selector(performSearch), with: nil, afterDelay: 0.3)
    }
    
    @objc private func performSearch() {
        onSearch?(searchTextField.text ?? "")
    }
    
    @objc private func prevTapped() {
        onPrev?()
    }
    
    @objc private func nextTapped() {
        onNext?()
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
}

// MARK: - UITextFieldDelegate
extension FindBarView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        onNext?()
        return true
    }
}
