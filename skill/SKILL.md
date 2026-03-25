# Claude 技能：研发测试闭环（Dev-Test Loop，v1）

## 目标

用两个专职子代理（Developer Agent + Tester Agent）模拟研发和测试岗位的互相配合，自动完成「实现 → 测试 → 反馈 → 修复 → 验收」闭环，无需用户来回传话。

## 成功标准

- [ ] Developer 基于任务需求实现代码变更
- [ ] Tester 写测试、跑测试、输出测试报告
- [ ] 发现失败 → 自动生成修复请求 → Developer 修复 → Tester 重跑，直到通过或达到上限
- [ ] 整个闭环不需要用户介入，最终输出一份验收报告

## 基本信息

| 项目 | 内容 |
|------|------|
| 技能名称 | 研发测试闭环 — Developer + Tester 双代理自动迭代 |
| 技能类型 | 高阶编排技能（Subagent 协调） |
| 执行文件 | `~/Desktop/硅基员工/工作技能/研发测试闭环/pattern_devtest_loop.md` |
| 工作区目录 | `/tmp/devtest_<session_id>/`（每次任务独立） |
| 最大迭代轮次 | 默认 5 轮，可配置 |

## 触发词

- "用研发测试闭环做这个"
- "帮我实现 [功能]，要自动测试"
- "devtest [任务描述]"
- "让研发和测试协作完成 [任务]"
- "开启研发测试双代理"

## 输入要求

1. **任务描述**（必须）：要实现什么功能 / 修复什么 bug
2. **目标代码库路径**（必须）：在哪个项目里做变更
3. **测试框架**（可选）：pytest / jest / go test / 不指定则自动探测
4. **验收标准**（可选）：不指定则用「所有测试通过」作为验收标准
5. **最大轮次**（可选，默认 5）

## 约束与原则

- Orchestrator（主 Claude）负责协调和最终判断，不自己写代码
- Developer Agent 只负责写代码，不跑测试
- Tester Agent 只负责写和跑测试，不改业务代码
- 两个 Agent 通过结构化 JSON 文件通信，不靠自然语言描述传参
- 每轮结束后 Orchestrator 读取测试报告做路由决策（通过/修复/放弃）
- 超过最大轮次 → 停止并向用户报告卡点，不无限循环

## 完整工作流

详见 `pattern_devtest_loop.md`

## 输出物

| 文件 | 说明 |
|------|------|
| `session.json` | 当前轮次、状态、历史摘要 |
| `dev_output.json` | Developer 每轮的变更摘要 |
| `test_report.json` | Tester 每轮的测试结果（pass/fail/coverage） |
| `fix_request.json` | Tester 发给 Developer 的修复清单 |
| `验收报告.md` | 最终交付给用户的闭环报告 |
