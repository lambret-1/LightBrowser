import UIKit

/// 调试日志查看页面
class DebugLogViewController: UIViewController {
    
    private let textView = UITextView()
    private let toolbar = UIToolbar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "调试日志"
        view.backgroundColor = .systemBackground
        // 添加关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(closeVC)
        )
        setupUI()
        loadLog()
    }
    
    @objc private func closeVC() {
        dismiss(animated: true)
    }
    
    private func setupUI() {
        // 工具栏
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        let copyItem = UIBarButtonItem(title: "复制", style: .plain, target: self, action: #selector(copyLog))
        let shareItem = UIBarButtonItem(title: "分享", style: .plain, target: self, action: #selector(shareLog))
        let deleteItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearLog))
        let refreshItem = UIBarButtonItem(title: "刷新", style: .plain, target: self, action: #selector(loadLog))
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [copyItem, flexible, shareItem, flexible, deleteItem, flexible, refreshItem]
        toolbar.tintColor = .systemBlue
        
        // 日志文本视图
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            textView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }
    
    @objc private func loadLog() {
        let log = DebugLogger.shared.readLog()
        textView.text = log
        // 滚动到底部
        if !log.isEmpty {
            let bottom = NSRange(location: log.count - 1, length: 1)
            textView.scrollRangeToVisible(bottom)
        }
        title = "调试日志 (\(DebugLogger.shared.logSize()))"
    }
    
    @objc private func copyLog() {
        DebugLogger.shared.copyLog()
        showToast("已复制到剪贴板")
    }
    
    @objc private func shareLog() {
        let log = DebugLogger.shared.readLog()
        let activityVC = UIActivityViewController(activityItems: [log], applicationActivities: nil)
        activityVC.popoverPresentationController?.barButtonItem = toolbar.items?[2]
        present(activityVC, animated: true)
    }
    
    @objc private func clearLog() {
        let alert = UIAlertController(title: "确认清空", message: "确定要清空所有调试日志吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { _ in
            DebugLogger.shared.clearLog()
            self.loadLog()
            self.showToast("日志已清空")
        })
        present(alert, animated: true)
    }
    
    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = UIFont.systemFont(ofSize: 14)
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            toast.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.3, animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}
