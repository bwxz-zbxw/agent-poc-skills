---
name: "poc-evalscope"
description: "evalscope 评测子 skill：MMBench 多模态与 LongBench 长文两类基准。当主控路由到此工具、或用户要求跑多模态/长文质量评测（MMBench、LongBench、repobench-p）时使用。"
---

# evalscope 评测子 Skill

负责 `evalscope` 的两类评测：多模态（MMBench）、长文（LongBench repobench-p）。接收主控传入的 `task spec`，执行后返回 `result spec`。环境信息一律用占位符填充。

## 模式（task spec 的 mode）

| mode | 数据集 | 端点 | 关键差异 |
| --- | --- | --- | --- |
| mmbench | MMBench（cc 目录随机抽样） | `/v1/chat/completions` | 需要多模态模型；图片 base64 data URI |
| longbench | LongBench repobench-p | `/v1/completions` | 纯文本；长文，注意 max-tokens |

## 前置依赖

- 被测服务就绪（主控「阶段 1」保证）。
- `evalscope` 已安装（容器内）。
- **模型依赖**：MMBench 必须用多模态模型（纯文本模型会 400 报「not a multimodal model」）。
- 数据集已下载并预处理（见下）。

## 数据集下载与预处理

```bash
# 下载（modelscope）
modelscope download --model lmms-lab/MMBench --local_dir ./mmbench
modelscope download --model ZhipuAI/LongBench --local_dir ./longbench
# 下载后用 find 确认实际路径
```

预处理脚本（固定 seed 保证可复现）：
- MMBench：随机抽 200 个 cc 样本，生成含图片 base64 data URI 的 JSONL
- LongBench：随机抽 300 个 repobench-p 样本，拼接 context+input 为纯文本行 JSONL

（脚本路径与生成格式按目标机实际存放位置，见项目内预处理脚本。）

## 通用 evalscope 参数

- `--no-test-connection`：跳过连接测试（evalscope 用 `{"prompt":"hello"}` 打 chat 端点会 400）
- `--no-apply-chat-template`、`--no-timestamp`
- `--timeout 3600`（总超时）
- 冒烟先行：`--parallel 1 --number 1 --debug` 验证请求格式与响应

## 冒烟 → 正式

先冒烟（1 并发、1~2 样本），确认请求格式、响应、服务可用，再跑正式（多并发多样本）。

## MMBench 命令模板

```bash
evalscope --model <MODEL> --api-url http://<HOST>:<PORT>/v1/chat/completions \
  --eval-type opencompass --datasets <MMBENCH_DATASET> \
  --dataset-args '{"data_file":"<mmbench_cc_200>.jsonl"}' \
  --tokenizer-path <TOKENIZER_PATH> --max-tokens 1024 \
  --extra-args '{"enable_thinking": true}' \
  --no-apply-chat-template --no-test-connection --no-timestamp \
  --parallel <1|5|10> --timeout 3600 --work-dir <OUT_DIR>
```

要点：
- 端点必须是 `/v1/chat/completions`（`/v1/completions` 不支持图片）
- `--extra-args '{"enable_thinking": true}'` 开启思考模式
- 典型并发：1 / 5 / 10 各 200 样本

## LongBench 命令模板

```bash
evalscope --model <MODEL> --api-url http://<HOST>:<PORT>/v1/completions \
  --eval-type opencompass --datasets <LONG_BENCH_DATASET> \
  --dataset-args '{"data_file":"<repobench_p300>.jsonl"}' \
  --tokenizer-path <TOKENIZER_PATH> --max-tokens 128 \
  --extra-args '{"enable_thinking": false}' \
  --no-apply-chat-template --no-test-connection --no-timestamp \
  --parallel <1|5> --timeout 3600 --work-dir <OUT_DIR>
```

要点：
- 端点用 `/v1/completions`（repobench-p 走 line_by_line 格式）
- 服务默认思考模式时，`--extra-args '{"enable_thinking": false}'` 关闭，避免思考 token 占满 max-tokens 影响测量
- 长文 max-tokens 128；典型并发 1 / 5 各 300 样本

## 结果解析与坑清单

- 结果从 evalscope 输出目录（work-dir）读取评分/准确率。
- 代理转 400→500：纯文本模型打多模态会被代理转为 500；要拿原始错误信息可直连 P 节点。
- 连接测试失败根因：chat 端点要求 `messages` 字段，evalscope 默认 `{"prompt":...}` 会 400 → 始终加 `--no-test-connection`。
- 思考模式下推理 token 会占满 max-tokens，影响 TPOT 测量 → 按需显式开关 `enable_thinking`。

## 输出（result spec）

```json
{
  "task_id": "task_mmbench_p0",
  "status": "pass",
  "metrics": { "score": 67.5, "concurrency": 5, "samples": 200 },
  "artifacts": ["./out_p0/result.json", "./run_mmbench.log"],
  "notes": ""
}
```

## 完成判据

- [ ] 冒烟通过（请求格式/响应/服务可用）
- [ ] 各并发档评分/准确率已提取
- [ ] 结果与日志已保留