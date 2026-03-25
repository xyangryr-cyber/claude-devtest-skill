# Pattern：研发测试闭环执行工作流（v1）

## 架构概览

```
用户任务
   ↓
Orchestrator（主 Claude）
   ├── 初始化工作区 + session.json
   ├── Round 1..N
   │   ├── → Developer Agent（读 task.md + fix_request.json → 写代码 → 写 dev_output.json）
   │   ├── → Tester Agent（读 dev_output.json → 写/跑测试 → 写 test_report.json）
   │   └── Orchestrator 读 test_report.json 做路由决策
   └── 输出 验收报告.md
```

两个 Agent 通过 `/tmp/devtest_<id>/` 下的 JSON 文件通信，不通过自然语言来回传话。

---

## Phase 0：初始化

### 0.1 Orchestrator 收集上下文

```
输入：
- task_description: 用户的任务描述
- project_path: 目标代码库路径
- test_framework: pytest / jest / go test / auto（默认 auto）
- max_rounds: 最大迭代轮次（默认 5）
- acceptance_criteria: 验收标准（默认"所有测试通过"）
```

### 0.2 Orchestrator 探测环境

```bash
# 自动探测测试框架（如果 test_framework=auto）
ls <project_path>                        # 看项目结构
cat <project_path>/package.json          # Node 项目
cat <project_path>/pyproject.toml        # Python 项目
cat <project_path>/go.mod                # Go 项目
```

### 0.3 创建工作区

```bash
SESSION_ID=$(date +%Y%m%d_%H%M%S)
WORKSPACE=/tmp/devtest_${SESSION_ID}
mkdir -p ${WORKSPACE}
```

### 0.4 写入 task.md 和 session.json

**task.md**：
```markdown
# 任务描述
<task_description>

# 目标项目
<project_path>

# 测试框架
<test_framework>

# 验收标准
<acceptance_criteria>
```

**session.json**（初始）：
```json
{
  "session_id": "<SESSION_ID>",
  "project_path": "<project_path>",
  "test_framework": "<test_framework>",
  "acceptance_criteria": "<acceptance_criteria>",
  "max_rounds": 5,
  "current_round": 0,
  "status": "in_progress",
  "history": []
}
```

**fix_request.json**（初始，空）：
```json
{
  "round": 0,
  "issues": [],
  "context": "首次实现，请根据 task.md 完成功能"
}
```

---

## Phase 1：Developer Agent（每轮执行）

### Developer Agent Prompt 模板

```
你是一名资深软件工程师（Developer Agent）。你的职责是**只写业务代码**，不跑测试。

## 工作区
- 任务描述：读取 <WORKSPACE>/task.md
- 修复请求：读取 <WORKSPACE>/fix_request.json
- 当前轮次：Round <N>

## 执行步骤

1. **读取任务**
   - 读 task.md 理解需求
   - 读 fix_request.json 理解上一轮测试反馈（Round 1 时 issues 为空，根据任务直接实现）

2. **阅读现有代码**
   - 读取目标项目的相关文件
   - 理解现有架构和代码风格

3. **实现代码变更**
   - 遵循项目已有代码风格
   - 只修改 fix_request.json 中指出的问题，不做多余变更
   - 如果是 Round 1，实现完整功能

4. **输出 dev_output.json**

写入 <WORKSPACE>/dev_output.json：
{
  "round": <N>,
  "changed_files": [
    {
      "path": "<相对于项目根目录的文件路径>",
      "action": "created | modified | deleted",
      "summary": "<这个文件改了什么>"
    }
  ],
  "implementation_notes": "<实现思路简述，帮助 Tester 理解要测什么>",
  "known_limitations": "<你知道的潜在问题或边界情况>",
  "suggested_test_focus": "<建议 Tester 重点验证的点>"
}

## 约束
- 不要运行测试命令
- 不要修改测试文件（除非 fix_request 明确要求）
- 变更必须完整，不留 TODO 占位
- 写完后停止，等 Tester 接手
```

### Orchestrator 调用方式

```python
# 伪代码
developer_result = Agent(
    subagent_type="general-purpose",
    prompt=DEVELOPER_PROMPT.format(
        workspace=WORKSPACE,
        project_path=project_path,
        round=current_round
    )
)
# 验证 dev_output.json 存在且格式正确
```

---

## Phase 2：Tester Agent（每轮执行）

### Tester Agent Prompt 模板

```
你是一名资深 QA 工程师（Tester Agent）。你的职责是**写测试、跑测试、报告结果**，不修改业务代码。

## 工作区
- 任务描述：读取 <WORKSPACE>/task.md
- Developer 输出：读取 <WORKSPACE>/dev_output.json
- 当前轮次：Round <N>
- 测试框架：<test_framework>

## 执行步骤

1. **读取上下文**
   - 读 task.md 理解验收标准
   - 读 dev_output.json 理解本轮变更了什么、建议测试重点

2. **检查现有测试**
   - 扫描项目测试目录
   - 判断哪些测试需要新增、哪些需要更新

3. **写测试代码**（如果需要）
   - 覆盖 dev_output.json 中 `suggested_test_focus` 指出的关键路径
   - 覆盖正常路径 + 边界情况 + 异常处理
   - 如果已有测试文件，在其中添加新用例，不要覆盖已有用例

4. **运行测试**
   ```bash
   # pytest
   cd <project_path> && python -m pytest -v --tb=short 2>&1

   # jest
   cd <project_path> && npx jest --verbose 2>&1

   # go test
   cd <project_path> && go test ./... -v 2>&1
   ```

5. **输出 test_report.json 和 fix_request.json**

**test_report.json**：
{
  "round": <N>,
  "status": "passed | failed | error",
  "total_tests": <int>,
  "passed": <int>,
  "failed": <int>,
  "failures": [
    {
      "test_name": "<测试名称>",
      "file": "<测试文件路径>",
      "error_message": "<原始错误信息>",
      "root_cause_hypothesis": "<你判断的根因>"
    }
  ],
  "test_output_summary": "<测试命令的原始输出（截取关键部分，不超过 500 字）>",
  "new_tests_written": ["<新增的测试文件路径>"],
  "coverage_notes": "<覆盖了哪些路径，遗漏了什么>"
}

**fix_request.json**（仅当 status=failed 时写入）：
{
  "round": <N>,
  "issues": [
    {
      "priority": "P0 | P1 | P2",
      "test_name": "<失败的测试>",
      "file_to_fix": "<业务代码文件路径>",
      "problem": "<问题描述>",
      "expected_behavior": "<期望的行为>",
      "actual_behavior": "<实际的行为>",
      "fix_suggestion": "<修复建议（方向性，不要替代 Developer 写代码）>"
    }
  ],
  "context": "<给 Developer 的整体提示>"
}

## 约束
- 不要修改业务代码文件（dev_output.json 中 changed_files 涉及的文件）
- 测试必须真实运行，不能伪造结果
- 如果运行时报环境错误（依赖缺失等），写入 fix_request.json issues 中，priority=P0
- 写完后停止，等 Orchestrator 读取结果
```

### Orchestrator 调用方式

```python
# 伪代码
tester_result = Agent(
    subagent_type="general-purpose",
    prompt=TESTER_PROMPT.format(
        workspace=WORKSPACE,
        project_path=project_path,
        test_framework=test_framework,
        round=current_round
    )
)
# 读取 test_report.json 做路由决策
```

---

## Phase 3：Orchestrator 路由决策

每轮 Tester Agent 完成后，Orchestrator 读取 `test_report.json`：

```python
report = read_json(f"{WORKSPACE}/test_report.json")

if report["status"] == "passed":
    → Phase 4：输出验收报告，结束

elif report["status"] == "failed":
    if current_round >= max_rounds:
        → Phase 4：输出卡点报告，告知用户
    else:
        current_round += 1
        → 更新 session.json
        → 返回 Phase 1（Developer 读 fix_request.json 修复）

elif report["status"] == "error":
    # 环境/配置错误，不是代码问题
    → 停止并向用户报告具体错误，等待人工介入
```

### session.json 每轮更新

```json
{
  "current_round": <N>,
  "status": "in_progress | passed | failed | error",
  "history": [
    {
      "round": 1,
      "dev_summary": "<changed_files 摘要>",
      "test_result": "passed | failed",
      "failed_count": 0
    }
  ]
}
```

---

## Phase 4：输出验收报告

### 4.1 通过时的验收报告

```markdown
# 验收报告 — <任务描述摘要>

## 结果：✅ 通过

- **总轮次**：<N> 轮
- **最终测试**：<total> 个，全部通过

## 变更摘要

<最后一轮 dev_output.json 中 changed_files 的列表>

## 测试覆盖

<test_report.json 中 coverage_notes>

## 迭代历史

| 轮次 | Developer 做了什么 | 测试结果 | 失败数 |
|------|-------------------|---------|-------|
| 1    | ...               | failed  | 3     |
| 2    | ...               | passed  | 0     |

## 工作区

`<WORKSPACE>` — 保留所有中间文件可供查阅
```

### 4.2 卡点时的报告

```markdown
# 验收报告 — <任务描述摘要>

## 结果：⚠️ 未能在 <max_rounds> 轮内通过

## 当前卡点

<最后一轮 test_report.json 中 failures 列表>

## 需要人工决策

<列出 P0 问题及建议>

## 已完成的工作

<变更文件列表 + 已通过的测试>
```

---

## 完整轮次示例（Python 项目，pytest）

```
Round 1:
  Developer → 实现功能 → dev_output.json (changed: src/foo.py)
  Tester   → 写 tests/test_foo.py → 跑 pytest → 3 failed
  Orchestrator → 写 fix_request.json, 进入 Round 2

Round 2:
  Developer → 读 fix_request → 修复 src/foo.py
  Tester   → 跑 pytest → 1 failed (边界情况)
  Orchestrator → 写 fix_request.json, 进入 Round 3

Round 3:
  Developer → 修复边界情况
  Tester   → 跑 pytest → 全部通过 ✅
  Orchestrator → 输出验收报告
```

---

## 调用方式（Orchestrator 实现要点）

当主 Claude 触发此技能时，按如下方式执行：

1. **收集参数**（可向用户澄清）
2. **初始化工作区**（本地执行）
3. **循环调用两个 Agent**：
   ```
   for round in 1..max_rounds:
       call Developer Agent (Agent tool, general-purpose)
       call Tester Agent (Agent tool, general-purpose)
       route based on test_report.json
   ```
4. **输出验收报告**

每个 Agent 调用都用 `Agent` 工具的 `general-purpose` 类型，给完整的 prompt（含工作区路径、项目路径、当前轮次）。两个 Agent 串行执行（Tester 依赖 Developer 的输出），不并行。

---

## 注意事项

- **环境隔离**：Tester 跑测试前检查依赖是否安装（pip install / npm install / go mod tidy）
- **测试幂等**：Tester 不删除上一轮写的测试，只追加新用例
- **修复最小化**：Developer 每轮只修复 fix_request 中列出的问题，不顺手重构
- **超时保护**：单个 Agent 调用如果超过合理时间没有输出结果文件，视为 error，停止并报告
- **TDD 兼容**：如果用户明确要求 TDD，调换顺序：Tester 先写空测试（全红）→ Developer 实现 → Tester 跑测试

## TDD 变体（可选）

将执行顺序改为：
```
Round 1: Tester 先写测试（全红）→ Developer 实现 → Tester 重跑
Round 2+: 同标准流程
```

触发词：在任务描述中加"用 TDD"或"先写测试"。
