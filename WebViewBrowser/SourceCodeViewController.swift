//
//  SourceCodeViewController.swift
//  轻量浏览器 - 网页源码查看器
//

import UIKit

class SourceCodeViewController: UIViewController {
    private let html: String
    private let pageTitle: String
    
    private var textView: UITextView!
    private var searchBar: UISearchBar!
    private var searchBottomConstraint: NSLayoutConstraint!
    private var isSearching = false
    
    init(html: String, title: String) {
        self.html = html
        self.pageTitle = title
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupSearchBar()
        setupTextView()
        loadSource()
    }
    
    private func setupNavigationBar() {
        title = "网页源码"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain,
                target: self,
                action: #selector(shareSource)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "doc.on.doc"),
                style: .plain,
                target: self,
                action: #selector(copySource)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "magnifyingglass"),
                style: .plain,
                target: self,
                action: #selector(toggleSearch)
            )
        ]
    }
    
    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.placeholder = "搜索源码..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.isHidden = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupTextView() {
        textView = UITextView()
        textView.font = UIFont(name: "Menlo", size: 12)
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadSource() {
        // 大文件截断保护：超过500KB时截断
        var displayHTML = html
        if html.count > 500000 {
            displayHTML = String(html.prefix(500000)) + "\n\n... (源码过长，已截断，完整长度: \(html.count) 字符)"
        }
        textView.text = displayHTML
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
    
    @objc private func close() {
        dismiss(animated: true)
    }
    
    @objc private func copySource() {
        UIPasteboard.general.string = html
        showToast("源码已复制")
    }
    
    @objc private func shareSource() {
        let activityVC = UIActivityViewController(activityItems: [html], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }
    
    @objc private func toggleSearch() {
        isSearching.toggle()
        searchBar.isHidden = !isSearching
        if isSearching {
            searchBar.becomeFirstResponder()
            UIView.animate(withDuration: 0.2) {
                self.textView.contentInset.top = 44
            }
        } else {
            searchBar.resignFirstResponder()
            searchBar.text = ""
            UIView.animate(withDuration: 0.2) {
                self.textView.contentInset.top = 0
            }
        }
    }
    
    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
}

extension SourceCodeViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else {
            textView.text = html.count > 500000 ? String(html.prefix(500000)) + "\n\n... (源码过长，已截断)" : html
            return
        }
        // 高亮搜索结果
        let fullText = html.count > 500000 ? String(html.prefix(500000)) : html
        let attributedString = NSMutableAttributedString(string: fullText)
        attributedString.addAttribute(.font, value: UIFont(name: "Menlo", size: 12)!, range: NSRange(location: 0, length: fullText.count))
        
        let searchRange = fullText.startIndex..<fullText.endIndex
        var searchCount = 0
        var currentIndex = searchRange.lowerBound
        
        while let range = fullText.range(of: searchText, options: .caseInsensitive, range: currentIndex..<searchRange.upperBound) {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow, range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
            searchCount += 1
            currentIndex = range.upperBound
            if searchCount >= 100 { break } // 最多高亮100个结果
        }
        
        textView.attributedText = attributedString
        
        // 跳转到第一个匹配项
        if let firstRange = fullText.range(of: searchText, options: .caseInsensitive) {
            let nsRange = NSRange(firstRange, in: fullText)
            textView.scrollRangeToVisible(nsRange)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
