---
name: "poc-vllmbench"
description: "vllm bench serve 基准测试子 skill：随机/前缀数据集基准，产出 TTFT/TPOT/E2EL 分布与吞吐。当主控路由到此工具、或用户要求跑 vllm bench 基准 / 20tps 达标 / E2EL 分布时使用。"
---

# vllm bench 基准测试子 Skill

负责 `vllm bench serve` 基准测试（模式 `bench`）。接收主控传入的 `task spec`，执行后返回 `result spec`。环境信息一律用占位符填充。

## 模式（task spec 的 mode）

| mode | 场景 | 典型参数 | 核心指标 |
| --- | --- | --- | --- |
| bench | 基准/20tps | 128k 输入 / 4k 输出，prefix 0%，并发 4 起 | TTFT / TPOT / E2EL 分布、吞吐 |

## 前置依赖

- 被测服务就绪（主控「阶段 1」保证）。
- 已安装 vLLM（`vllm bench serve` 可用），且能访问被测服务入口端口。

## 长度与并发约定

- 20tps 需求：输入 128k、输出 4k，`max_seq_length=1048576`。
- **总请求 K = 4×最大并发 J**。
- 20tps 达标判据：`(输出总吞吐 ÷ J) ≥ 20 tok/s`（等价 TPOT ≤ 50ms）。

## 执行命令模板

```bash
vllm bench serve --backend openai-chat --base-url http://<HOST>:<PORT> \
  --endpoint /v1/chat/completions --model <MODEL> --served-model-name <MODEL> \
  --tokenizer <MODEL_PATH> --dataset-name random \
  --random-input-len <L> --random-output-len <O> --random-range-ratio <0|...> \
  --num-prompts <K> --request-rate inf --max-concurrency <J> \
  --percentile-metrics ttft,tpot,itl,e2el --save-result --save-detailed \
  --result-dir <RESULT_DIR>
```

关键参数：
- `--dataset-name random`：随机数据集；`--random-range-ratio` 控制长度抖动比例（0 = 定长）
- `--num-prompts <K>` / `--max-concurrency <J>`：总请求 / 最大并发
- `--save-result --save-detailed --percentile-metrics ttft,tpot,itl,e2el`：保存完整分布与明细
- 需测 prefix 缓存时，改用带 `--prefix-test` 的两阶段方式（预热空白表 + 全量表，取全量）

## 结果解析

产物：
- 控制台 `Serving Benchmark Result` 汇总表（TTFT/TPOT/ITL/E2EL 的 mean/median/p90/p99）
- `--save-result` JSON、`--save-detailed` 明细

要点：
- vllm bench 不输出平均系统并发，需用 Little's Law 反推：
  **平均系统并发 = (总请求数 × 平均E2EL) ÷ 基准总时长**
- 「系统并发」= 平均在途请求数，区别于「最大并发 J」与「瞬时峰值并发」
- 输出总吞吐 ÷ J 用于 20tps 判据

## 调参（逼近 TTFT/TPOT 门槛）

1. **固定 max concurrency 与总请求，调 `request_rate`（初值 ~2.0）逼近 TTFT 门槛**
2. TPOT 随 J 增大而增大；若 20tps 不达标，**降低 J** 以提升 `输出总吞吐 ÷ J`
3. **PD 分离一律走代理端口**（如 12321/3999，或 `deploy.yaml` 的 `proxy.port`），不只高并发；直连 P 节点 9000 会导致 TTFT 恶化
4. 日志含实测数据，**保留勿删**；结果目录独立，防互覆盖

## 坑清单

1. PD 分离直连 P 节点（无论并发大小）→ TTFT 剧增，必须走代理口
2. 长度超限 → 写 `max_seq_length=1048576`（1M 输入场景另注意 1048480 上限放大）
3. 交互 shell `LD_PRELOAD=libjemalloc` 致崩溃 → 非交互启动
4. 用户名/卡冲突 → 测前 `npu-smi info` 确认

## 输出（result spec）

```json
{
  "task_id": "task_128k_4k_20tps",
  "status": "pass",
  "metrics": { "ttft_avg": 1.2, "ttft_p99": 2.0, "tpot_avg": 48, "e2el_avg": 3.4, "out_throughput": 8230, "per_user_tps": 20.6 },
  "artifacts": ["./result_dir/...json", "./run_vllmbench.log"],
  "notes": "输出总吞吐/J=20.6 tok/s 达标"
}
```

## 完成判据

- [ ] TTFT/TPOT/E2EL 分布已提取（mean/median/p90/p99）
- [ ] 20tps 判据已换算（输出总吞吐 ÷ J）
- [ ] 日志与结果 JSON 已保留