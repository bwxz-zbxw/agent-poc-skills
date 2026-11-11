---
name: "poc-case"
description: "POC 案例检索模块：在提供往期测试用例表时，确认①待测项是否已测过（有则直接复用）、②是否有相近场景可参考（提取种子参数降低测试成本）。当编排器进入阶段②、或需要检索历史 case 时调用。"
---

# 案例检索模块 Skill（阶段 ②）

在提供往期用例表时，对每个待测项做两件事：**是否已测过（复用）**、**是否有相近场景（种子参数）**。核心价值是「不盲目摸并发」，用历史数据降低测试成本。

## 数据源（两层）

| 文件 | 是否入仓库 | 大小量级 | 内容 | 何时读 |
| --- | --- | --- | --- | --- |
| `cases/index.yaml` | **否**（整个 `cases/` 目录被 `.gitignore` 排除） | ~20 KB | **第1层清单**：每个「模型+部署」一条，下挂场景档位数组，含 `seed_c`(达标档最大并发) / `passed` | **总是先读这个**，用于判 hit / near / none |
| `cases/library/<model>__<deployment>.yaml` | **否**（同上） | 1~20 KB/个 | **第2层明细**：该部署的完整并发扫档曲线（`points`） | **按需**，只读命中的那 1 个文件 |

> `cases/` 目录不存在 = 本机没有案例库 → 所有待测项直接判 `none`，从初始档开始压（不报错、不猜测）。
> 两个文件的字段与行格式见下方说明。

**读取纪律（省 token 的关键）**：

1. 先读 `index.yaml`（~20KB）：按 `model` + `dep` + `in/out/rr` 找到候选桶，拿到 `n`（档位数）、`seed_c`（种子并发）、`passed`；
2. **只有需要更多细节时才读** `library/<对应文件>`：要完整的 TTFT/TPOT 曲线、p90、单卡 TPS、实际命中率时；
3. 不要把 `library/` 整个目录读进来——那是 100KB+，按需只读一个文件。

### index.yaml 行格式（定长数组，省掉重复 key）

```yaml
# 顶部 images: 镜像索引（iNN -> 全名 + 是否可公开拉取）
images:
  i16: { tag: "quay.io/ascend/vllm-ascend:v0.30.0rc2-a5-openeuler", public: true }
  i17: { tag: "vllm-ascend:dev-26.1.0.day20260817-A5-py311-openEuler24.03-lts-aarch64", public: false }

index:
# [in, out, rr, slo_ttft_s, slo_tpot_ms, tool, n, seed_c, seed_tps, passed, img]
- model: "GLM-5.2"
  dep: glm52-1p1d
  file: library/glm-5.2__glm52-1p1d.yaml
  buckets:
  - [1000, 1000, 0.0, 6.0, 20.0, aisbench, 1, 96, 266.0, true, i16]
```

> ⚠️ 写库时注意：上例的 `model/dep/file` 必须是**块级映射**（按行展开）。
> 不能写成 `- { model: "x", dep: y }` 再换行接 `buckets:` —— flow 映射在同一行已闭合，
> 后面再挂块级键是**非法 YAML**，解析直接报 `Sequence item without - indicator`。

### 镜像登记（复现的关键）

每条 case 都必须能查到"当时用的什么镜像"，否则无法复现。为避免每行重复长字符串：

- **`index.yaml` 顶部 `images:` 字典**存 `iNN → {tag, public}`，行里只写 `img: iNN`；
- `public: true` → 可直接 `docker pull`；`public: false` → 内部构建/私有仓库，**复现时需换成可获取的等价镜像**；
- 一个场景档位内若用过多个镜像：`img` 取众数，另附 `imgs: [i10, i11]` 列出全部；
- **新增 case 时必填 `img`**：镜像不在字典里就先加字典项再引用。

复现流程：读 case 的 `img` → 查 `images[img].tag` → `public=false` 则先找等价公开镜像 → 按 `deployments/<dep>/` 起服务。

### library 文件列序（首行 `columns:` 已声明，勿猜）

```
[c, k, req, ttft, ttft90, tpot, tpot90, thr, tps, hit, ok]
```
c=并发 k=总请求 req=request_rate ttft/tpot=ms(avg) ttft90/tpot90=ms(p90)
thr=输出吞吐(tok/s) tps=单卡TPS hit=实际 prefix 命中率 ok=是否满足该场景时延门槛

> library 里的 `buckets[].img` 与 index 用同一套 `iNN` 编号，无需重复长名。

### 隐私铁律（写库前必查）

- 不记录任何可回溯到具体单位或个人的信息（名称、代号、编号一律不写）
- 人名 / 工号 / SSH 账号 / 机器 IP / 内网机器名 → **一律不写**
- 权重路径 → 不写（写 `model`，路径见 `poc-orchestrator/env.local.yaml` 的 `env.weights`）
- 截图 / 原始 log / json → 留用户侧，不写入 skill
- **落盘门禁**：写入前用敏感词（单位/项目名称 / 人名 / IP / 工号）反查一遍，确认零命中

## 输入契约

```json
{
  "items": [
    { "model": "DeepSeek-V4-Flash", "deployment": "PD分离",
      "scenario": { "input_len": 16384, "output_len": 1024, "repeat_rate": 0 } }
  ]
}
```

## 匹配维度与打分（判断「相近」）

按以下维度做匹配，得分越高越相近（阈值可调）：

| 维度 | 权重 | 说明 |
| --- | --- | --- |
| model + deployment + mode | 硬条件 | 不一致则不视为相近 |
| input_len 档位 | 高 | 落入同档（如 16k/64k/128k）|
| output_len 档位 | 高 | 同上 |
| repeat_rate 档位 | 中 | prefix 场景关键 |
| 并发区间 | 中 | 决定种子并发 |

## 三种结论与动作

| 结论 | 判据 | 动作 |
| --- | --- | --- |
| 命中（已测过） | 场景几乎一致、有完整历史结果 | 复用历史 `metrics`，跳过测试 → 直达阶段 ④ 回填 |
| 相近（可参考） | 主要维度匹配、指标达标 | 提取该 case 的 `best_params`（最优并发档等）作**种子参数**，传给阶段 ③ |
| 无 | 无相近 | 无种子，从初始档开始，阶段 ③ 自行离散档位打点 |

> 有 `points` 明细的 case：从中取 **`ok: true` 且并发最大** 的点作种子；若整条 case 全部 `ok: false`，取吞吐最高点作"上限参考"，并提示该场景历史未达标。
> 注意：`index.yaml` 里已预算好 `seed_c`（达标档最大并发）与 `passed`，**先直接用它们**；只有当你想核对曲线或取 p90/单卡 TPS 时才去读 `library/` 明细。

## 输出契约

```json
{
  "item_id": "task_16k_j128",
  "verdict": "near",                       // hit | near | none
  "reuse_metrics": null,                   // hit 时填充，直接用于回填
  "seed_params": { "concurrency": 128, "request_rate": 2.0 },  // near 时填充
  "ref_case_id": "case_16k_J128_20261012", // 参考来源
  "notes": "已测过，直接复用"
}
```

## 危险动作

本阶段只读索引，无危险动作；「新增 case 索引」需告知用户后写入。

## 完成判据

- [ ] 每个待测项给出 hit / near / none 结论
- [ ] hit 已带复用结果，near 已带种子参数