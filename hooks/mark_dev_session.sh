#!/bin/bash
# PostToolUse Hook: 当 Claude 调用 Edit 或 Write 工具后触发
# 作用：把当前工作目录写入标记文件，告诉 Stop Hook "这次会话有代码变更"
#
# Claude Code 会把工具信息通过 stdin 传进来（JSON 格式），我们用 jq 解析
# 但这里只需要记录项目路径，不需要解析工具详情

PENDING_FILE="/tmp/.devtest_pending"

# 读取当前工作目录（Claude Code 会设置 CLAUDE_PROJECT_DIR 环境变量）
# 如果没有，就用 HOME 作为兜底
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "$PROJECT_DIR" > "$PENDING_FILE"

exit 0
