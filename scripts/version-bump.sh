#!/usr/bin/env bash
# =============================================================================
# 轻量浏览器 - 三段语义化版本递增脚本
# 规范：主版本.次版本.补丁号，补丁位 0~9，满9自动进位
# 示例：1.0.9 → 1.1.0；1.9.9 → 2.0.0；16.17.27 → 16.18.0（补丁>9强制进位）
# =============================================================================
set -euo pipefail

# ---------- 配置区 ----------
PLIST_PATH="${1:-WebViewBrowser/Info.plist}"
VERSION_KEY="CFBundleShortVersionString"
BUILD_KEY="CFBundleVersion"

# ---------- 颜色输出 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------- 前置校验 ----------
if [ ! -f "$PLIST_PATH" ]; then
    log_error "Info.plist 不存在: $PLIST_PATH"
    exit 1
fi

if ! command -v /usr/libexec/PlistBuddy &>/dev/null; then
    log_error "PlistBuddy 不可用，当前环境非 macOS"
    exit 1
fi

# ---------- 版本合法性校验 ----------
validate_version() {
    local ver="$1"
    # 必须是三段纯数字：x.y.z
    if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "版本格式非法（非三段数字）: $ver"
        exit 1
    fi
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    # 主版本、次版本必须 >= 0
    if [ "$major" -lt 0 ] || [ "$minor" -lt 0 ]; then
        log_error "版本号存在负数: $ver"
        exit 1
    fi
    return 0
}

# ---------- 版本递增核心逻辑 ----------
bump_version() {
    local ver="$1"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"

    # 补丁位 >= 9 时进位（兼容历史补丁位>9的情况，强制进位归零）
    if [ "$patch" -ge 9 ]; then
        patch=0
        # 只有次版本原本为9时才向主版本进位
        if [ "$minor" -eq 9 ]; then
            minor=0
            major=$((major + 1))
        else
            minor=$((minor + 1))
        fi
    else
        patch=$((patch + 1))
    fi

    echo "${major}.${minor}.${patch}"
}

# ---------- 读取当前版本 ----------
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :${VERSION_KEY}" "$PLIST_PATH" 2>/dev/null || true)
if [ -z "$CURRENT_VERSION" ]; then
    log_error "无法读取 ${VERSION_KEY}"
    exit 1
fi

log_info "当前版本: $CURRENT_VERSION"
validate_version "$CURRENT_VERSION"

# ---------- 计算新版本 ----------
NEW_VERSION=$(bump_version "$CURRENT_VERSION")
log_info "递增后版本: $NEW_VERSION"
validate_version "$NEW_VERSION"

# ---------- 防回退校验 ----------
# 新版本必须大于当前版本（数值比较）
compare_versions() {
    local v1="$1" v2="$2"
    local m1 n1 p1 m2 n2 p2
    IFS='.' read -r m1 n1 p1 <<< "$v1"
    IFS='.' read -r m2 n2 p2 <<< "$v2"
    [ "$m1" -gt "$m2" ] && return 0
    [ "$m1" -lt "$m2" ] && return 1
    [ "$n1" -gt "$n2" ] && return 0
    [ "$n1" -lt "$n2" ] && return 1
    [ "$p1" -gt "$p2" ] && return 0
    return 1
}

if ! compare_versions "$NEW_VERSION" "$CURRENT_VERSION"; then
    log_error "版本递增异常：新版本 $NEW_VERSION 不大于当前版本 $CURRENT_VERSION"
    exit 1
fi

# ---------- 安全写入 Plist ----------
log_info "写入 ${VERSION_KEY}=${NEW_VERSION}"
/usr/libexec/PlistBuddy -c "Set :${VERSION_KEY} ${NEW_VERSION}" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :${BUILD_KEY} ${NEW_VERSION}" "$PLIST_PATH"

# ---------- 写入后回读校验 ----------
VERIFY_VERSION=$(/usr/libexec/PlistBuddy -c "Print :${VERSION_KEY}" "$PLIST_PATH")
if [ "$VERIFY_VERSION" != "$NEW_VERSION" ]; then
    log_error "写入校验失败：期望 $NEW_VERSION，实际 $VERIFY_VERSION"
    exit 1
fi

log_info "版本递增完成: $CURRENT_VERSION → $NEW_VERSION"
# 输出新版本供流水线后续步骤使用
echo "$NEW_VERSION"
