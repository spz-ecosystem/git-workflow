#!/bin/bash
# gw_credentials.sh — git-workflow 的凭据单一入口（2026-10-25）
#
# 解析顺序（先命中先用，绝不联网猜）：
#   1. 密钥库：$TRAE_SECRETS_DIR/github.token，默认 ~/.config/trae-secrets/github.token
#      （Windows 侧回退 /mnt/c/Users/HP/.config/trae-secrets/github.token）
#   2. 环境变量 GITHUB_TOKEN / GH_TOKEN
#   3. gh CLI 已登录的 token（gh auth token）
#
# 用法： source "$(dirname "$0")/gw_credentials.sh"; t=$(gw_token)

TRAE_SECRETS_DIR="${TRAE_SECRETS_DIR:-$HOME/.config/trae-secrets}"

gw_secret_file() {
    local f="$TRAE_SECRETS_DIR/github.token"
    if [ -s "$f" ]; then printf '%s' "$f"; return 0; fi
    f="/mnt/c/Users/HP/.config/trae-secrets/github.token"
    if [ -s "$f" ]; then printf '%s' "$f"; return 0; fi
    return 1
}

gw_token() {
    local f
    if f="$(gw_secret_file)"; then
        tr -d '\r\n' < "$f"
        return 0
    fi
    if [ -n "$GITHUB_TOKEN" ]; then printf '%s' "$GITHUB_TOKEN"; return 0; fi
    if [ -n "$GH_TOKEN" ]; then printf '%s' "$GH_TOKEN"; return 0; fi
    gh auth token 2>/dev/null
}

# 让同一 shell 里的 git 与 gh 都拿到同一份凭据（调用方可选）
gw_export_env() {
    local t
    t="$(gw_token)" || return 1
    [ -n "$t" ] || return 1
    export GH_TOKEN="$t"
    export GITHUB_TOKEN="$t"
}
