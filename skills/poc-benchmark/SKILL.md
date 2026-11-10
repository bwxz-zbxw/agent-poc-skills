---
name: "poc-benchmark"
description: "POC 性能测试分发模块（性能测试总入口）：接收测试项与可选种子参数，按工具路由到 L2 工具子 skill（aisbench/vllmbench/evalscope）执行并收集 result spec。当编排器进入阶段③、或需要跑性能/评测测试时调用。"
---

# 性能测试分发模块 Skill（阶段 ③）

性能测试模块是 L2 工具子 skill 的**分发器**——本身不写工具执行细节，只按工具路由到对应子 skill，并统一收集结果。

## 挂载的工具子 skill（L2）

| 工具 | 子 skill | 模式 |
| --- | --- | --- |
| aisbench_auto_tools_prefix | `poc-aisbench` | prefix_hitrate / concurrency |
| vllm bench serve | `poc-vllmbench` | bench |
| evalscope | `poc-evalscope` | mmbench / longbench |
| 调参方法论（吞吐摸高） | `poc-throughput-tuning` | throughput_tap / fixed_concurrency |
| （新增工具） | `poc-<新工具>` | —（扩展位） |

## 输入契约

接收阶段 ② 传来的「测试项 + 可选种子参数」：

```json
{
  "task_id": "task_16k_j128",
  "tool": "aisbench",
  "mode": "concurrency",
  "params": { "input_len": 16384, "output_len": 1024, "repeat_rate": 0, "dp": 4, "npu_num": 8 },
  "seed_params": { "concurrency": 128, "request_rate": 2.0 },   // 来自阶段②，可为空
  "thresholds": { "ttft_s": 6.0, "tpot_ms": 50 },
  "output_dir": "./outputs/task_16k_j128"
}
```

## 请求数约定

- **总请求数 = 最大并发 × 4**（即 K = 4J）。固定最大并发为 J 时，总请求数一律设为 4J。

## 分发规则

1. 根据 `tool` 查本模块注册表（见上表）映射到子 skill。
2. 有 `seed_params` → 作为初始并发档起点；无 → 从初始档开始，由子 skill 按其步进策略离散档位打点。
3. 调子 skill：`Skill(name="<子skill>", args="<task spec JSON>")`，收集返回的 `result spec`。
4. 汇总多个测试项的 `result spec` 列表，回传编排器，供阶段 ④ 回填。

## 输出契约

```json
[
  {
    "task_id": "task_16k_j128",
    "status": "pass",
    "metrics": { "ttft_avg": 4.2, "tpot_avg": 31, "throughput": 3120 },
    "artifacts": ["./outputs/task_16k_j128/details.json", "./run_16k_j128.log"]
  }
]
```

## 危险动作

跑测试本身通常自动；但**执行前**仍须经 `poc-safety` 准入——尤其服务启动/占用共享卡/长时间（≥30min）任务需人工确认。清理服务、删日志等破坏性动作一律先确认。

## 扩展

新增测试工具 = 在 `skills/` 新建 `poc-<工具>/SKILL.md` + 在本模块「挂载表」登记一行。本模块与编排器均无需改动逻辑。

## 完成判据

- [ ] 每个测试项拿到子 skill 的 `result spec`
- [ ] 种子参数已用于初始档（来自阶段②时）