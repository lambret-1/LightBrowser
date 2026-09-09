# 轻量浏览器 - 制品说明文档

## 制品清单

每次生产构建产出以下制品：

| 制品 | 文件名 | 说明 |
|------|--------|------|
| 未签名 IPA | `WebViewBrowser-unsigned-v{版本}.ipa` | 主制品，供全能签重签名 |
| 元数据 JSON | `build-metadata.json` | 版本、commit、SHA256、构建信息 |
| Git Tag | `v{版本}` | 版本标记，与 Release 一一对应 |
| Draft Release | GitHub Release | 草稿状态，人工审核后发布 |

## SHA256 校验使用说明

### 为什么需要校验
确保下载的 IPA 文件完整、未被篡改、与 CI 构建产物一致。

### 校验方法

**macOS / Linux：**
```bash
shasum -a 256 WebViewBrowser-unsigned-v1.0.0.ipa
```

**Windows（PowerShell）：**
```powershell
Get-FileHash -Algorithm SHA256 .\WebViewBrowser-unsigned-v1.0.0.ipa
```

将输出的哈希值与 Release 页面或 `build-metadata.json` 中的 `sha256` 字段对比，一致则制品可信。

## 全能签导入 IPA 注意事项

### 前置条件
1. 已安装全能签（TrollStore 或其他签名工具）
2. 有可用的签名证书（个人开发者证书 / 企业证书）
3. iOS 设备已信任对应证书

### 导入步骤
1. 从 GitHub Release 下载未签名 IPA
2. 打开全能签
3. 选择「导入 IPA」→ 选择下载的文件
4. 配置签名证书和描述文件
5. 点击「签名」→ 生成已签名 IPA
6. 安装到 iOS 设备

### 常见问题

**Q: 导入提示「IPA 结构损坏」**
A: 检查下载是否完整，重新下载并校验 SHA256。

**Q: 安装后闪退**
A: 检查证书是否有效、设备 UDID 是否在描述文件中、是否已信任证书。

**Q: 全能签不识别 IPA**
A: 确保 IPA 内是 `Payload/xxx.app` 结构，本项目 CI 产出的 IPA 已符合该标准。

## 制品元数据 JSON 说明

### 字段含义

| 字段 | 类型 | 说明 |
|------|------|------|
| `project` | string | 项目名称固定为 LightBrowser |
| `version` | string | 三段语义版本号 |
| `commit` | string | Git 短哈希（7位） |
| `build_time` | string | UTC 时间，ISO 8601 格式 |
| `build_duration_seconds` | number | 编译耗时（秒） |
| `artifact.name` | string | IPA 文件名 |
| `artifact.size_bytes` | number | 文件大小（字节） |
| `artifact.sha256` | string | SHA256 哈希值 |
| `build_environment.runner_os` | string | 构建系统 |
| `build_environment.sdk` | string | 编译 SDK |
| `build_environment.signing` | string | 签名状态（固定 unsigned） |

### 使用场景
- 自动化校验：脚本读取 JSON 对比本地文件哈希
- 制品溯源：通过 commit 哈希定位代码版本
- 构建分析：统计构建耗时趋势

## iOS 15+ 部署说明

### 最低系统要求
- iOS 15.0 及以上
- 支持 iPhone / iPad
- 支持 TrollStore 永久签名安装

### 功能兼容性
| 功能 | iOS 15 | iOS 16 | iOS 17+ |
|------|--------|--------|---------|
| WKWebView 核心 | ✅ | ✅ | ✅ |
| 网页导出 PDF | ✅（iOS 14+） | ✅ | ✅ |
| 下载管理 | ✅ | ✅ | ✅ |
| 四级缓存 | ✅ | ✅ | ✅ |
| App Proxy VPN | ✅ | ✅ | ✅ |
| 翻译系统 | ✅ | ✅ | ✅ |

### 已知限制
- iOS 14 及以下：部分 API 不可用，建议升级
- 企业证书签名：需注意证书有效期和设备数量限制
- TrollStore：仅支持特定 iOS 版本和设备

## Draft Release 使用指引

### 什么是 Draft Release
Draft（草稿）Release 是 GitHub 的预发布状态：
- 普通用户看不到（仅仓库协作者可见）
- 不会触发 App 内更新检测
- 可随时编辑、删除
- 人工审核确认后点击「Publish release」转为正式发布

### 审核清单
发布前请确认：
- [ ] 版本号正确（与 Info.plist 一致）
- [ ] IPA 文件可正常下载
- [ ] SHA256 校验通过
- [ ] build-metadata.json 完整
- [ ] 更新日志准确描述本次变更
- [ ] 无敏感信息（证书、密钥等）泄露

### 发布流程
1. 进入 GitHub Releases 页面
2. 找到 Draft 状态的 Release
3. 点击「Edit」
4. 审核内容无误后
5. 点击「Publish release」
6. 发布完成，App 内更新检测可识别新版本

### 回滚方法
如果发布后发现严重问题：
1. 删除有问题的 Release
2. 删除对应的 Git Tag
3. 修复代码后重新 push 到 main 触发新构建
4. 新版本发布后，旧版本用户会收到更新提示
