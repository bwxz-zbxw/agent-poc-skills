---
name: "poc-throughput-tuning"
description: "吞吐摸高调优子 skill：在给定时延内摸高吞吐的调参方法论——允许/不允许调 rr 两类场景的摸高流程、拐点判定、rr 设定，以及固定并发长跑。当客户需求是给定时延摸高吞吐、需要找最优并发与 rr 时使用。"
---

# 吞吐摸高调优子 Skill

本 skill 是**调参方法论**，不是某种测试工具的执行器——它配合 `poc-aisbench` / `poc-vllmbench` 使用，在它们产出的 TTFT/TPOT/吞吐数据基础上做「并发 + rr」调优决策。挂在 `poc-benchmark`（阶段③）下。

## 需求分类（先判断属于哪种）

| 类型 | 特征 | 处理 |
| --- | --- | --- |
| A. 给定时延摸高吞吐（允许调 rr） | 可改请求频率 rr | 走「允许调 rr」流程 |
| B. 给定时延摸高吞吐（不允许调 rr） | rr 固定 | 走「不允许调 rr」流程 |
| C. 固定并发长跑 | 并发固定 | 服务化脚本备好后写 sh 脚本挂长跑摸测 |

## 流程 A · 允许调 rr

1. **摸并发（先不看 ttft）**：一直调并发，直到出现下列任一即停：
   - (1) TPOT 达到客户限制
   - (2) 增大并发后吞吐不升反降（拐点）
2. **拐点确认**：
   - 情况 (2) 要注意性能波动，建议在拐点处**多测两次**确认
   - 拐点典型特征：TPOT 的 **p90 / p99 时延突变、TPOT 更离散**
3. **停顿点后处理**（(1)(2) 相同）：
   - TTFT 未超限制（或超限 ≤1s）→ 登记数据交差
   - TTFT 超限制 >1s → 通过**调 rr 降低 ttft**
4. **rr 的设定**（需要调 rr 时）：
   - 方式一：rr=0 测试中若观察到最高 rps，登记「比最高 rps 略高一点」的值
   - 方式二：未观察则从结果汇总表取请求吞吐，一般设 **rr ≈ 吞吐的 1.2 倍**

## 流程 B · 不允许调 rr

登记性能 = 到达下列任一限制时的性能：
1. TPOT **或** TTFT 达到客户限制
2. 增大并发后吞吐不升反降（拐点）

## 流程 C · 固定并发长跑

服务化脚本准备就绪后，写 sh 脚本挂长跑摸测即可（无需动态调并发/rr）。

## 合格容差（略超限判合格）

TTFT / TPOT 略超客户限制阈值时，达到以下容差即可判合格登记，无需继续调优或多测：

- **TTFT 超限 ≤ 1s** → 合格
- **TPOT 超限 ≤ 1ms** → 合格

超过该容差才继续调优（调 rr 降 ttft / 调并发控 tpot）。

## 输入契约（承接 benchmark 的 task spec）

```json
{
  "task_id": "task_16k_tap",
  "demand_type": "throughput_tap",     // throughput_tap | fixed_concurrency
  "rr_adjustable": true,               // 是否允许调 rr
  "thresholds": { "ttft_s": 6.0, "tpot_ms": 50 },
  "seed_params": { "concurrency": 128 }
}
```

## 输出契约

```json
{
  "task_id": "task_16k_tap",
  "status": "pass",
  "best_params": { "concurrency": 132, "request_rate": 2.4 },
  "metrics": { "ttft_avg": 5.8, "tpot_avg": 48, "throughput": 3200 },
  "notes": "并发132为拐点；rr=2.4 将 ttft 压回限制内"
}
```

## 坑清单

1. 拐点处性能波动大 → 多测两次，勿凭单次数据定拐点
2. 拐点常伴随 TPOT p90/p99 突变、更离散 → 作为拐点辅助判据
3. rr=0 时未观察最高 rps → 用汇总表吞吐 ×1.2 兜底设 rr
4. 摸并发阶段「先不看 ttft」，避免被 ttft 干扰而过早停住

## 完成判据

- [ ] 找到最优并发（或拐点）与 rr（如需）
- [ ] TTFT/TPOT 达标对照清晰，最优参数已登记
- [ ] 拐点若出现已多测确认