---
name: "poc-aisbench"
description: "aisbench_auto_tools_prefix 压测子 skill：prefix cache 命中率与并发门槛两类测试，产出 TTFT/TPOT/吞吐/命中率指标。当主控路由到此工具、或用户直接要求跑 aisbench 压测 / prefix cache / 并发达标测试时使用。"
---

# aisbench 压测子 Skill

负责 `aisbench_auto_tools_prefix` 工具的两类测试。接收主控传入的 `task spec`，执行后返回 `result spec`。环境信息一律用占位符（`<HOST>`、`<CONTAINER>`、`<TOOL_REPO>` 等），执行时按目标机实际值填充。

## 模式（task spec 的 mode）

| mode | 场景 | 典型参数 | 核心指标 |
| --- | --- | --- | --- |
| prefix_hitrate | prefix cache 命中率 | 256k/1、512k/1、1M/1，repeat_rate 0.95/0.99 | TTFT、实际命中率 |
| concurrency | 并发门槛 | 16k/1k、64k/1k、128k/1k，request_rate 2.0 调 J | TTFT、TPOT、吞吐 |

## 前置依赖

- 被测服务就绪（主控「阶段 1」保证）。
- 工具已安装：`aisbench` + `aisbench_auto_tools_prefix`（每台机器一次性）。
- `config.py` 已按目标环境配置（见下）。

## 工具源码（已随本 skill 打包）

`./tools/aisbench_auto_tools_prefix/` 内已收录必要文件（无需再从仓库 clone）：

- `aisbench_test.py`（主压测脚本）
- `cal_prefix_hit_rate.py`（命中率计算）
- `config.py`（配置，见下）
- `data_picker.py` / `default_api.py` / `generate_dataset.py` / `save_file.py`（数据与结果辅助）
- `README.md`（工具说明，含参数表、命令示例、FAQ）

运行前仍依赖 `aisbench`（`ais-bench-benchmark`）环境：

```bash
git clone https://github.com/AISBench/benchmark.git && cd benchmark && \
pip3 install -e ./ --use-pep517 && pip3 install -r requirements/api.txt -r requirements/extra.txt
```

**兼容修复**：aisbench 3.0.0 已移除 `--num-warmups`，在 `aisbench_test.py` 的 `generate_aisbench_command` 中删除该参数。

## config.py 每次测试前必改（`<TOOL_REPO>/config.py`）

- `OUTPUT_DIR`：每场景独立目录（如 `./outputs/task_16k_J128`），防互覆盖
- `HOST_IP`：执行测试命令的本机实际 IP（不能写 127.0.0.1）
- `HOST_PORT`：请求入口 —— 9000 直连 P / 代理口（1P1D DP 代理口 12321 等 / 3999 proxy）；**高并发必须走代理口**
- `POD_INFO`：各节点 metrics 端口列表（命中率统计用）
- `MODEL_NAME`、`MODEL_PATH`、`DATASET_PATH`、`WORK_PATH`、`API_KEY`

**DeepSeek-V4-Flash-0731 · 3p1d 部署的实际值**（详见 `poc-capability/deployments/dsv4-flash-0731-3p1d/deploy.yaml`）：

```python
MODEL_NAME = "dsv4_0905"
MODEL_PATH = "<WEIGHTS_PATH>"
HOST_IP = "<HOST_31>"     # 请求都打 proxy
HOST_PORT = "14258"
POD_INFO = ["<HOST_31>:9000", "<HOST_31>:9001", "<HOST_32>:9000", "<HOST_32>:9001"]
```

## 执行（统一容器内运行）

宿主机 python 缺 transformers 会失败；长任务 nohup 后台 + 独立日志（日志含实测数据，**保留勿删**）：

```bash
nohup docker exec <CONTAINER> bash -c 'cd <TOOL_REPO> && python3 aisbench_test.py <参数>' > <场景>.log 2>&1 &
```

**prefix_hitrate 模板**（rr=0 无速率限制）：

```bash
python3 aisbench_test.py --input_len <L> --output_len <O> --data_num <K> --concurrency <J> \
  --request_rate 0 --dataset_type prefix_cache --repeat_rate <0.95|0.99> \
  --prefix_test --dp <DP> --npu_num <NPU>
```

**concurrency 模板**（rr=2.0 固定）：

```bash
python3 aisbench_test.py --input_len <L> --output_len <O> --data_num <K> --concurrency <J> \
  --request_rate 2.0 --dataset_type prefix_cache --repeat_rate <0|0.9> \
  --prefix_test --dp <DP> --npu_num <NPU>
```

参数要点：
- `--data_num = 4×--concurrency`（K=4J）
- `--prefix_test`：先用同并发预热公共前缀写 KV cache 再跑全量；日志两张表，**取第二张（全量）为正式结果**
- `--dp`：PD 分离 DP4 服务**必带 `--dp 4`**，漏带只预热 1 个 DP 域 → 命中率 ~25%
- `--npu_num`：8 卡部署带 `--npu_num 8`（单卡吞吐计算）
- 长度上限：`input_len + output_len ≤ max_model_len`；1M 场景取 **1048480**（写 1048576 会 400）
- 长输入首轮冷启动 prefill 很慢（1M 首请求约 356s），属正常

## 结果解析

产物：
- `<场景>.log`、`aisbench.log` / `aisbench_all.log`
- 明细 JSON：`outputs/<OUTPUT_DIR>/<exp时间戳>/performances/vllm-api-stream-chat/gsm8kdataset_details.json`

提取：
- **TTFT avg/median/p90/p99**：主日志汇总段，或明细 JSON 的 `prefill_latency`
- **实际命中率**：`grep -A 20 "Prefix cache hit detail" aisbench.log`，**第二张表**为正式测试后快照（首张为预热后快照）
- **TPOT / 输出吞吐 / 单卡吞吐**（总吞吐 ÷ npu_num）/ **成功率**
- 命中率略低于目标（如 93.7% vs 95%）由固定前缀+随机尾缀+块边界导致，属工具正常偏差

## 调参（摸 TTFT/TPOT 门槛）

1. **rr 固定 2.0，只调最大并发 J**（rr 2→256 对 TTFT 几乎无影响），K=4J 跟随
2. **离散档位打点**：按档位递增 J（如 80→128→132→136→144→160）逼近门槛，用「超限档」对照确认最优档
3. **TPOT 约束换算**：需求「20tps」等价于 `(输出总吞吐 ÷ J) ≥ 20 tok/s`（即 TPOT ≤ 50ms）；TPOT 随 J 增大而增大，降低 J 可满足
4. **高并发必须走代理入口**：直连 P 节点 9000 会因 prefill API 队列过载导致 TTFT 剧增（6.3s→145.6s 量级）
5. 每档独立 OUTPUT_DIR + 独立日志，便于对照留档

## 坑清单

1. 残留 vllm 进程 → 进程组 kill（`kill -9 -- -<PGID>`）
2. 交互 shell 的 `LD_PRELOAD=libjemalloc` 致 worker 随机崩 → 非交互启动 / `unset LD_PRELOAD`
3. 静态 hixlep 端点网卡故障期起不来 → 动态 URMA `ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'`
4. DP 模式加载错误卡配置 → 打 patch 使 `utils.py` 用 `torch.npu.current_device()`；`/etc/hixlep/ub_endpoint_npu_{0..7}.json` 就位
5. 卡被他人占用 → 测前 `npu-smi info`，占满需用户确认
6. 脚本 CRLF 行尾 → `sed -i 's/\r$//'`
7. 1M 输入写 1048576 → 400；取 1048480
8. 直连 P 9000 高并发 → TTFT 恶化，走代理口
9. 漏 `--dp 4` → 命中率 ~25%
10. `HOST_IP` 写 127.0.0.1 → 失败；写执行机实际 IP
11. 宿主机跑 aisbench → 缺依赖失败；必须在容器内
12. 日志勿删：测试日志含实测数据，非临时文件

## 输出（result spec）

```json
{
  "task_id": "task_16k_J128",
  "status": "pass",
  "metrics": { "ttft_avg": 4.2, "ttft_p99": 6.1, "tpot_avg": 31, "hit_rate": 0.937, "throughput": 3120 },
  "artifacts": ["./outputs/task_16k_J128/details.json", "./run_16k_J128.log"],
  "notes": "命中率 93.7% 略低于 95%，属正常偏差"
}
```

## 完成判据

- [ ] 每场景成功率 100%（失败先排查 500/错误，必要时重试或上报）
- [ ] TTFT/TPOT 达标，记录最优档 J 与超限对照档
- [ ] 命中率已记录（目标 vs 实测）
- [ ] 日志与明细 JSON 已保留