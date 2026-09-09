#!/usr/bin/env bash
# =============================================================================
# 轻量浏览器 - README 更新日志自动插入脚本
# 在 README.md 顶部插入结构化版本日志，旧日志依次下沉
# =============================================================================
set -euo pipefail

# ---------- 参数 ----------
README_PATH="${1:-README.md}"
VERSION="${2:?版本号不能为空}"
COMMIT_HASH="${3:?Commit哈希不能为空}"
BUILD_TIME="${4:?构建时间不能为空}"
IPA_SHA256="${5:-未生成}"
CHANGE_SUMMARY="${6:-性能优化与稳定性提升}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ ! -f "$README_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} README.md 不存在: $README_PATH"
    exit 1
fi

# ---------- 生成日志条目 ----------
LOG_ENTRY="## v${VERSION} 更新日志
- 版本：v${VERSION}
- Commit：\`${COMMIT_HASH}\`
- 构建时间：${BUILD_TIME}
- IPA SHA256：\`${IPA_SHA256}\`
- 更新内容：${CHANGE_SUMMARY}
"

# ---------- 找到 "## 当前版本" 行，在其后插入 ----------
# 使用临时文件确保原子写入
TMP_FILE=$(mktemp)

# 标记是否已插入
INSERTED=0
while IFS= read -r line || [ -n "$line" ]; do
    # 更新当前版本号行
    if [[ "$line" =~ ^##\ 当前版本： ]]; then
        echo "## 当前版本：v${VERSION}" >> "$TMP_FILE"
        if [ "$INSERTED" -eq 0 ]; then
            echo "" >> "$TMP_FILE"
            echo "$LOG_ENTRY" >> "$TMP_FILE"
            INSERTED=1
        fi
        continue
    fi
    echo "$line" >> "$TMP_FILE"
done < "$README_PATH"

# 如果没找到插入点，在文件开头插入
if [ "$INSERTED" -eq 0 ]; then
    {
        echo "$LOG_ENTRY"
        echo ""
        cat "$README_PATH"
    } > "$TMP_FILE"
fi

# 原子替换
mv "$TMP_FILE" "$README_PATH"
echo -e "${GREEN}[INFO]${NC} README 更新日志已插入: v${VERSION}"
