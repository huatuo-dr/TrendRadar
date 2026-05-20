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

# Run git with token auth when GITHUB_TOKEN is set; otherwise use system credentials
git_with_auth() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        export GIT_TERMINAL_PROMPT=0
        git -c "credential.helper=!f() { echo username=x-access-token; echo password=${GITHUB_TOKEN}; }; f" "$@"
    else
        git "$@"
    fi
}

if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "检测到 GITHUB_TOKEN，将使用 Token 进行 Git 认证"
else
    echo "未检测到 GITHUB_TOKEN，将使用本机已配置的 Git 凭据"
fi

# 1. 同步远程仓库内容
echo "正在同步远程仓库..."
git_with_auth pull

# Check if git pull was successful
if [ $? -ne 0 ]; then
    echo "Git pull 失败，请检查网络、冲突或 Token 权限。"
    exit 1
fi

# 2. 执行命令：uv run main.py
echo "正在执行 uv run main.py..."
uv run main.py

# Check if execution was successful
if [ $? -ne 0 ]; then
    echo "uv run main.py 执行失败。"
    exit 1
fi

# 3. git add.; git commit -m "xxxx年xx月xx日构建"; git push
echo "正在提交代码..."

# Get current date in the format YYYY年MM月DD日
COMMIT_MSG="$(date +'%Y年%m月%d日构建')"

git add .
git commit -m "$COMMIT_MSG"
git_with_auth push

echo "流程完成！"
