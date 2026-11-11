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
| 调参方法论（摸高 / 并发门槛） | `poc-throughput-tuning` | throughput_tap / concurrency_threshold / fixed_concurrency |
| （新增工具） | `poc-<新工具>` | —（扩展位） |

> **职责边界**：工具子 skill 只管「按给定参数执行 + 产出指标」（avg 与 p90）；**档位怎么走、rr 怎么定、拐点怎么判全部归 `poc-throughput-tuning`**。
> 因此 `mode=concurrency`（aisbench 并发门槛）时，实际是「aisbench 执行 + throughput-tuning 决策」两者配合。

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

## 容器命名与复用约定

多人 agent 协作时，为避免在同一台服务器上**重复创建容器**，容器名必须**确定性**（同一「模型 × 部署方式」在任何 agent 手里算出同一个名字）。

**命名规则**：`poc-<部署目录名>`，即 `poc-` 前缀 + `poc-capability/deployments/<模型-部署>/` 的目录名。
例：部署目录 `dsv4-flash-0731-3p1d` → 容器名 `poc-dsv4-flash-0731-3p1d`。

**复用判断（启动 / 测试前必做）**：

```bash
docker ps -a --filter name=poc-<部署目录名>
```

- 已存在且运行中 → **直接复用**，跳过 `docker_run.sh`，不重复创建
- 已存在但已停止 → 优先 `docker start <容器名>` 复用；确需重建再清理
- 不存在 → 才走部署脚本创建

部署侧（`poc-capability` 的 `docker_run.sh`）创建时也必须用同一命名，两侧保持一致。

## 扩展

新增测试工具 = 在 `skills/` 新建 `poc-<工具>/SKILL.md` + 在本模块「挂载表」登记一行。本模块与编排器均无需改动逻辑。

## 完成判据

- [ ] 每个测试项拿到子 skill 的 `result spec`
- [ ] 种子参数已用于初始档（来自阶段②时）