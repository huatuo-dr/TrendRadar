#!/bin/bash

# Ensure we are executing from the project root directory
# This allows the script to be run from anywhere (e.g., ./scripts/update_repo.sh or cd scripts; ./update_repo.sh)
cd "$(dirname "$0")/.." || exit 1
echo "当前目录：$(pwd)"

# Load optional .env (GITHUB_TOKEN for HTTPS auth)
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

GIT_RETRY_MAX="${GIT_RETRY_MAX:-5}"
GIT_RETRY_DELAY="${GIT_RETRY_DELAY:-3}"

# Run git with token auth when GITHUB_TOKEN is set; otherwise use system credentials
git_with_auth() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        export GIT_TERMINAL_PROMPT=0
        git -c "credential.helper=!f() { echo username=x-access-token; echo password=${GITHUB_TOKEN}; }; f" "$@"
    else
        git "$@"
    fi
}

# Retry a single git command up to GIT_RETRY_MAX times
git_retry() {
    local attempt
    for ((attempt = 1; attempt <= GIT_RETRY_MAX; attempt++)); do
        if git_with_auth "$@"; then
            if [ "$attempt" -gt 1 ]; then
                echo "Git 操作成功（第 ${attempt}/${GIT_RETRY_MAX} 次尝试）: $*"
            fi
            return 0
        fi
        if [ "$attempt" -lt "$GIT_RETRY_MAX" ]; then
            local wait_sec=$((attempt * GIT_RETRY_DELAY))
            echo "Git 操作失败，${wait_sec} 秒后重试（${attempt}/${GIT_RETRY_MAX}）: $*"
            sleep "$wait_sec"
        fi
    done
    echo "Git 操作在 ${GIT_RETRY_MAX} 次尝试后仍失败: $*"
    return 1
}

# pull --rebase then push, with retry (aligned with crawler.yml)
git_retry_pull_rebase_push() {
    local branch="$1"
    local attempt
    for ((attempt = 1; attempt <= GIT_RETRY_MAX; attempt++)); do
        if git_with_auth pull --rebase origin "$branch" && git_with_auth push -u origin "$branch"; then
            if [ "$attempt" -gt 1 ]; then
                echo "推送成功（第 ${attempt}/${GIT_RETRY_MAX} 次尝试）"
            fi
            return 0
        fi
        if [ "$attempt" -lt "$GIT_RETRY_MAX" ]; then
            local wait_sec=$((attempt * GIT_RETRY_DELAY))
            echo "拉取或推送失败，${wait_sec} 秒后重试（${attempt}/${GIT_RETRY_MAX}）..."
            sleep "$wait_sec"
        fi
    done
    echo "拉取/推送在 ${GIT_RETRY_MAX} 次尝试后仍失败"
    return 1
}

# Return 0 if origin has the given branch
remote_branch_exists() {
    local branch="$1"
    git_with_auth ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1
}

if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "检测到 GITHUB_TOKEN，将使用 Token 进行 Git 认证"
else
    echo "未检测到 GITHUB_TOKEN，将使用本机已配置的 Git 凭据"
fi

BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
    echo "无法获取当前分支，已退出。"
    exit 1
fi
echo "当前分支: ${BRANCH}"

# 1. Sync remote (skip pull when branch does not exist on origin yet)
echo "正在同步远程仓库..."
if remote_branch_exists "$BRANCH"; then
    if ! git_retry pull --rebase origin "$BRANCH"; then
        echo "Git pull 失败，请检查网络、冲突或 Token 权限。"
        exit 1
    fi
else
    echo "远端尚无 origin/${BRANCH}，跳过初始 pull"
fi

# 2. Run main.py
echo "正在执行 uv run main.py..."
if ! uv run main.py; then
    echo "uv run main.py 执行失败。"
    exit 1
fi

# 3. Commit and push
echo "正在提交代码..."
COMMIT_MSG="$(date +'%Y年%m月%d日构建')"

git add .
if git diff --staged --quiet; then
    echo "无变更，跳过提交与推送。"
    echo "流程完成！"
    exit 0
fi

if ! git commit -m "$COMMIT_MSG"; then
    echo "git commit 失败。"
    exit 1
fi

echo "正在推送到 origin/${BRANCH}..."
if ! git_retry_pull_rebase_push "$BRANCH"; then
    echo "Git push 失败，请检查网络、冲突或 Token 权限。"
    exit 1
fi

echo "流程完成！"
