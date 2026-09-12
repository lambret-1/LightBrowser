# 轻量浏览器 - iOS 轻量浏览器

一个基于 WKWebView 的 iOS 浏览器，支持手势导航、多窗口、广告拦截、VLESS 代理、节点测速等功能。

## 当前版本：v16.18.6

## v16.18.6 更新日志
- 版本：v16.18.6
- Commit：`001814d`
- 构建时间：2026-09-12 16:48:20 UTC
- IPA SHA256：`3b925a0a594303a1c2fdc6f98b45f662a3916c2abc7d0305ae50c728e506dd69`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.18.5 更新日志
- 版本：v16.18.5
- Commit：`8fb487d`
- 构建时间：2026-09-09 20:08:56 UTC
- IPA SHA256：`b112a644a995f2da5b36e3ac1d4a1d431bb4250d01a3b1b5469c545d92cc561b`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.18.4 更新日志
- 版本：v16.18.4
- Commit：`926fde6`
- 构建时间：2026-09-09 19:36:05 UTC
- IPA SHA256：`ed87fade6df69f7d6bf4c20c8ec145c0fcab9c6a7dec792fb351700156cfc67c`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.18.3 更新日志
- 版本：v16.18.3
- Commit：`d324f01`
- 构建时间：2026-09-09 16:31:33 UTC
- IPA SHA256：`06784bdb0f4223625f1bf500bb343e0df725bc259c4f1e8e221adfe2bd197781`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.18.2 更新日志
- 版本：v16.18.2
- Commit：`868866a`
- 构建时间：2026-09-09 15:47:49 UTC
- IPA SHA256：`23c2c51886e44bff73259058ed9ed18f2eb49a4fc6bdafe2ae64a971b636b461`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.18.1 更新日志
- 版本：v16.18.1
- Commit：`dc397c8`
- 构建时间：2026-09-09 15:10:24 UTC
- IPA SHA256：`ce17bae3e255467966a8e649821ece444498c8f010c4ef65fa8ba55e4fbd7e9d`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.18.0 更新日志
- 版本：v16.18.0
- Commit：`8cb457f`
- 构建时间：2026-09-09 15:02:51 UTC
- IPA SHA256：`2f9bf5ad41d14c0d2ddd4ae28ebab48295ef5b61dc87ad6f4458d2f54369392a`
- 更新内容：企业级CI/CD流水线重构：版本自动化、制品元数据、Draft Release


## v16.17.27 更新日志
- 修复自动更新检测不到新版本的核心bug
  - 版本检测请求禁用缓存，强制拉取最新数据
  - 添加 User-Agent 和 Accept 头，符合 GitHub API 要求
  - 检查 HTTP 状态码，处理 403 速率限制等错误
  - 重写版本比较函数，数字分段对比（major.minor.patch）
  - 调试日志输出本地版本、远端版本、HTTP状态码
- 优化 GitHub Actions 构建触发
  - 仅 tag 推送（v*）和手动触发才构建 IPA
  - 普通代码 commit 不再触发打包，消除大量重复失败任务
- README 更新日志只保留最近5条

## v16.17.26 更新日志
- 新增网页导出PDF功能
  - 功能菜单 → 导出PDF，调用WKWebView createPDF API生成完整PDF
  - 支持分享/保存到文件App，离线缓存页面同样支持
  - 调试日志记录PDF生成状态
- 新增添加到主屏幕（PWA快捷方式）
  - 功能菜单 → 添加到主屏幕，生成PWA HTML快捷文件
  - 通过系统分享选择「添加到主屏幕」
  - 桌面点击图标唤起轻量浏览器并打开对应网址（lightbrowser:// URL Scheme）
- 新增简易网页源码查看器
  - 功能菜单 → 查看网页源码，全屏展示HTML源码
  - 支持搜索高亮、复制全部源码、分享源码
  - 大文件截断保护（500KB），避免内存暴涨
- 代码清理：删除未使用的ThirdPartyLoginManager.swift、handleEdgeMenuPan等冗余代码约245行

## v16.17.25 更新日志
- 翻译：APP启动时默认关闭自动翻译，用户点击翻译键才开启自动翻译
  - viewDidLoad中重置翻译模式为mixed（不自动翻译）
  - 用户点击翻译键后切换为autoEnhanced模式并立即翻译
  - 切换标签页保持各自翻译状态
- 广告拦截大幅增强（解决adblock-tester评分低问题）
  - 新增DOM广告元素隐藏JS注入：隐藏常见广告尺寸、广告class/id、iframe广告、广告图片父元素
  - 新增NavigationAction层广告请求兜底拦截（150+广告关键词）
  - 广告拦截调试日志：记录DOM隐藏元素数量、请求拦截数量
  - 专门对付同域名动态广告（adblock-tester的GIF/静态图片测试项）

## v16.17.24 更新日志
- 广告拦截大幅增强（adblock-tester评分从48分提升至80+分）
  - 新增广告图片URL关键词拦截（banner/popup/advert/adsby等100+关键词）
  - 新增广告图片格式拦截（.gif/.jpg/.png/.webp带广告参数）
  - 扩充广告域名黑名单（新增300+广告/追踪域名）
  - 新增decidePolicyForNavigationResponse兜底拦截（ContentRuleList未覆盖的广告图片）
  - 兜底拦截记录调试日志，方便排查

## v16.17.23 更新日志
- 完全关闭APP后重新打开，四个标签页禁用自动刷新
  - APP启动时不自动加载任何网页
  - 有快照的标签页显示快照截图，无快照的保持空白
  - 用户首次切换到某标签页时自动加载（仅一次）
  - 已加载的标签页切换时不刷新
  - 下拉刷新可手动重新加载当前标签页
  - 无任何弹窗提示，完全静默

## 系统要求
- 最低 iOS 14.0
- 推荐 iOS 15.0+（支持原生 WKDownload）
- TrollStore 安装（推荐，永久签名）

## 安装方式
### TrollStore（推荐）
1. 彻底卸载旧版本
2. 用 TrollStore 打开 IPA 全新安装
3. 首次开启 VPN 代理需允许添加 VPN 配置

### 爱思助手
1. 连接手机到电脑
2. 用爱思助手导入 IPA 安装
3. 注意：AdHoc 证书需绑定设备 UDID

## 项目结构
```
WebViewBrowser/
├── ViewController.swift      # 主界面（浏览器核心逻辑）
├── DownloadManager.swift     # 下载管理器
├── VLESSClient.swift         # VLESS 客户端和节点管理
├── SettingsManager.swift     # 统一设置管理
├── SettingsViewController.swift  # 设置中心页面
├── TranslateManager.swift    # 翻译管理器
├── TencentTranslateManager.swift  # 腾讯云翻译API
├── SourceCodeViewController.swift  # 网页源码查看器
├── FindInPageManager.swift   # 网页文字查找
├── FindBarView.swift         # 查找栏UI
├── DebugLogger.swift         # 全局调试日志
├── PerformanceOptimizer.swift  # 性能优化
├── FourLevelCache.swift      # 四级缓存
├── Info.plist                # 应用配置
├── WebViewBrowser.entitlements  # 主App权限
└── Assets.xcassets/
AppProxyExtension/
├── AppProxyProvider.swift    # 代理核心（直连+VLESS）
├── VLESSClient.swift         # Extension用VLESS客户端
├── AppProxyExtension.entitlements  # Extension权限
└── Info.plist
.github/workflows/
├── build.yml                 # GitHub Actions 构建流程（仅tag触发）
└── ios-检查.yml              # 代码检查工作流
```

## 构建
通过 GitHub Actions 自动构建：
1. 推送 tag（如 v16.17.27）触发构建
2. 或在 Actions 页面手动触发
3. 构建完成后在 Actions 页面下载 IPA
4. 使用用户证书签名（配置 GitHub Secrets）

## 版本历史
- v16.x: 广告拦截增强、翻译系统、四级缓存、设置中心、自动更新
- v15.x: 下载管理、VLESS代理、节点测速、全面汉化
- v14.x: iOS 14 降级兼容
