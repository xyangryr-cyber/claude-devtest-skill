#!/bin/bash
# Stop Hook: 当 Claude 结束整个回复后触发
# 作用：检查是否有代码变更标记，有则自动启动研发测试闭环

PENDING_FILE="/tmp/.devtest_pending"

# 没有标记文件，说明这次会话没有代码变更，什么都不做
if [ ! -f "$PENDING_FILE" ]; then
  exit 0
fi

# 读取项目路径
PROJECT_PATH=$(cat "$PENDING_FILE")

# 清除标记，避免重复触发
rm -f "$PENDING_FILE"

# 检查路径是否有效
if [ -z "$PROJECT_PATH" ] || [ ! -d "$PROJECT_PATH" ]; then
  exit 0
fi

# 在新终端中启动研发测试闭环
# 用 osascript 开新的 Terminal 窗口，避免阻塞当前会话
osascript -e "
tell application \"Terminal\"
  do script \"claude --print '用研发测试闭环验收刚才的代码变更，项目路径 $PROJECT_PATH' && exit\"
  activate
end tell
"

exit 0
