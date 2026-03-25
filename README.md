# Claude Code 研发测试闭环

> 用两个 AI 子代理模拟研发岗 + 测试岗，自动完成「实现 → 测试 → 反馈 → 修复 → 验收」闭环，不需要你来回传话。

## 效果

```
你说一句话
    ↓
Developer Agent 实现代码
    ↓
Tester Agent 写/跑测试 → 发现失败 → 写修复请求
    ↓
Developer Agent 读修复请求 → 修复代码
    ↓
Tester Agent 重跑 → 全部通过
    ↓
你收到验收报告
```

全程自动，最多跑 5 轮（可配置），卡住了才来找你。

## 快速安装

```bash
git clone https://github.com/xyangryr-cyber/claude-devtest-skill.git
cd claude-devtest-skill
chmod +x install.sh
./install.sh
```

## 使用方法

在 Claude Code 对话中说：

```
用研发测试闭环实现用户登录功能，项目路径 ~/my-app
```

或者直接让 Claude 改完代码，下一次对话**自动触发测试**（Hook 机制，无需任何操作）。

## 它包含什么

| 文件 | 作用 |
|------|------|
| `skill/SKILL.md` | 技能定义（触发词、输入要求、成功标准） |
| `skill/pattern_devtest_loop.md` | 完整执行流程（Developer / Tester 各自的 Prompt 模板） |
| `hooks/mark_dev_session.sh` | PostToolUse Hook：Claude 改了代码就写标记文件 |
| `hooks/trigger_devtest.sh` | Stop Hook：Claude 结束回复时检测标记，自动触发测试 |
| `install.sh` | 一键安装脚本 |

## Hook 机制

Claude Code 有一套生命周期 Hook 系统：

```
Claude 调用 Edit/Write 工具
    ↓ PostToolUse Hook 自动触发
    → 写入 /tmp/.devtest_pending（记录项目路径）

Claude 结束回复
    ↓ Stop Hook 自动触发
    → 检测标记文件存在 → 拉起新 claude 会话跑测试
```

这两个 Hook 注册在 `~/.claude/settings.json`，Claude Code 进程自动执行，Claude 本身不感知这个机制。

## 支持的测试框架

- Python → pytest（自动探测）
- Node.js → jest（自动探测）
- Go → go test（自动探测）

## 要求

- Claude Code（已安装）
- macOS（Stop Hook 用 osascript 开新终端，Linux 版本适配中）
