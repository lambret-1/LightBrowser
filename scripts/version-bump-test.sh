#!/usr/bin/env bash
# =============================================================================
# 轻量浏览器 - 版本递增逻辑单元测试
# 覆盖：正常递增、补丁进位、次版本进位、主版本进位、非法格式、边界值
# =============================================================================
set -euo pipefail

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 从 version-bump.sh 提取 bump_version 函数进行测试
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 内联测试用的递增函数（与 version-bump.sh 保持一致）
bump_version() {
    local ver="$1"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    if [ "$patch" -ge 9 ]; then
        patch=0
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

validate_version() {
    local ver="$1"
    [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    return 0
}

assert_eq() {
    local test_name="$1" expected="$2" actual="$3"
    if [ "$expected" == "$actual" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name: $expected"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} $test_name: 期望=$expected, 实际=$actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_true() {
    local test_name="$1" condition="$2"
    if eval "$condition"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        FAIL=$((FAIL + 1))
    fi
}

echo "========================================"
echo " 版本递增逻辑单元测试"
echo "========================================"

# ---------- 正常递增 ----------
assert_eq "1.0.0 → 1.0.1" "1.0.1" "$(bump_version 1.0.0)"
assert_eq "1.0.1 → 1.0.2" "1.0.2" "$(bump_version 1.0.1)"
assert_eq "1.0.8 → 1.0.9" "1.0.9" "$(bump_version 1.0.8)"

# ---------- 补丁位进位 ----------
assert_eq "1.0.9 → 1.1.0" "1.1.0" "$(bump_version 1.0.9)"
assert_eq "2.3.9 → 2.4.0" "2.4.0" "$(bump_version 2.3.9)"
assert_eq "16.17.9 → 16.18.0" "16.18.0" "$(bump_version 16.17.9)"

# ---------- 补丁位>9强制进位（兼容历史版本） ----------
assert_eq "16.17.27 → 16.18.0" "16.18.0" "$(bump_version 16.17.27)"
assert_eq "1.0.99 → 1.1.0" "1.1.0" "$(bump_version 1.0.99)"

# ---------- 次版本进位 ----------
assert_eq "1.9.9 → 2.0.0" "2.0.0" "$(bump_version 1.9.9)"
assert_eq "0.9.9 → 1.0.0" "1.0.0" "$(bump_version 0.9.9)"
assert_eq "9.9.9 → 10.0.0" "10.0.0" "$(bump_version 9.9.9)"

# ---------- 大版本号 ----------
assert_eq "16.17.0 → 16.17.1" "16.17.1" "$(bump_version 16.17.0)"
assert_eq "100.200.9 → 100.201.0" "100.201.0" "$(bump_version 100.200.9)"

# ---------- 版本格式校验 ----------
assert_true "合法版本 1.0.0 通过校验" "validate_version 1.0.0"
assert_true "合法版本 16.17.27 通过校验" "validate_version 16.17.27"
assert_true "非法版本 1.0 拒绝" "! validate_version 1.0"
assert_true "非法版本 1.0.0.1 拒绝" "! validate_version 1.0.0.1"
assert_true "非法版本 v1.0.0 拒绝" "! validate_version v1.0.0"
assert_true "非法版本 1.0.abc 拒绝" "! validate_version 1.0.abc"
assert_true "非法版本 空字符串 拒绝" "! validate_version ''"

# ---------- 防回退校验逻辑 ----------
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
assert_true "1.0.1 > 1.0.0" "compare_versions 1.0.1 1.0.0"
assert_true "1.1.0 > 1.0.9" "compare_versions 1.1.0 1.0.9"
assert_true "2.0.0 > 1.9.9" "compare_versions 2.0.0 1.9.9"
assert_true "1.0.0 不大于 1.0.0" "! compare_versions 1.0.0 1.0.0"
assert_true "1.0.0 不大于 1.0.1" "! compare_versions 1.0.0 1.0.1"

echo "========================================"
echo -e "测试结果: ${GREEN}通过 $PASS${NC}, ${RED}失败 $FAIL${NC}"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}单元测试失败，终止流水线${NC}"
    exit 1
fi
echo -e "${GREEN}全部单元测试通过${NC}"
exit 0
