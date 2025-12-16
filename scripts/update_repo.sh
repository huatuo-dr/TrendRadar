#!/bin/bash

# Ensure we are executing from the project root directory
# This allows the script to be run from anywhere (e.g., ./scripts/update_repo.sh or cd scripts; ./update_repo.sh)
cd "$(dirname "$0")/.." || exit 1

# 1. 同步远程仓库内容
echo "正在同步远程仓库..."
git pull

# Check if git pull was successful
if [ $? -ne 0 ]; then
    echo "Git pull 失败，请检查网络或冲突。"
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
git push

echo "流程完成！"
