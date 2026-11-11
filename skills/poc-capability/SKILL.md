---
name: "poc-capability"
description: "POC 能力确认模块：校验「模型+部署方式」是否在能力清单已记录，并校验运行环境信息（env 段：机器 IP/SSH 账号/权重路径/工作目录/通信网卡），有则返回可用测试工具与部署脚本（含镜像版本），无则明确告知用户并询问是否新增。当编排器进入阶段①、或需确认某模型部署方式是否可测时调用。"
---

# 能力确认模块 Skill（阶段 ①）

负责校验「模型 + 部署方式」是否在框架能力清单内。只做**匹配与告知**，不做测试执行。

## 数据源

1. `capabilities.yaml`（本目录）：可测「模型 × 部署方式」清单，每条含可用测试工具（指向 L2 子 skill）、部署脚本路径、镜像版本、卡分配（cards / p_cards / d_cards，混部不登记 P/D）。**仓库托管**：随 git 更新，安装时强制同步。
2. `deployments/<模型-部署>/`（本目录下）：该组合的**服务化启动脚本 + 镜像版本元数据**，供性能测试子 skill 查阅与实际拉起服务：
   - `start_all.sh`：完整原始脚本（脱敏后，多机 / 多实例一体），**始终存在**，作为可复现的兜底
   - `start_p.sh` / `start_d.sh`（PD 分离时）：按 `P节点:` / `D节点:` 切分出的单角色脚本
   - `deploy.yaml`：拓扑、端口、KV 端口、卡分配、权重路径、镜像、关键参数、测试约定
   - 同样**仓库托管**，随 git 更新
3. `../poc-orchestrator/env.local.yaml`：**运行环境信息**（机器 IP / SSH 账号 / 权重路径 / 工作目录 / 通信网卡 / 镜像仓库）。本地私有：gitignore、安装不覆盖；模板为同目录 `env.example.yaml`。

### 占位符约定（跨文件统一）

| 占位符 | 含义 | 运行时来源 |
| --- | --- | --- |
| `<HOST_A>` `<HOST_B>` … | 某台机器的 IP（按脚本内出现顺序编号） | `env.host_31` / `env.host_32` |
| `<NIC>` | HCCL/GLOO 通信网卡名 | `env.nic` |
| `<WEIGHTS_PATH>` | 权重目录 | `env.weights` |
| `<INTERNAL_REGISTRY>` | 内部镜像仓库域名 | `env.registry` |

**隐私铁律**：`capabilities.yaml` 与 `deployments/` 随仓库提交（仓库托管），**不得出现**真实单位/项目名称、人名/工号、机器 IP、内网机器名、含工号的权重路径、内部 registry 域名。新增部署脚本时先脱敏再落盘（门禁：敏感词反查零命中）。**真实值只写 `poc-orchestrator/env.local.yaml`，绝不写进这两个受管路径**——写进去就会被安装脚本同步覆盖，也会进仓库。

## 输入契约

```json
{
  "model": "DeepSeek-V4-Flash-0731",
  "deployment": "PD分离",
  "cards": 16,            // 【必填】总卡数：同模型同部署方式可能有多套卡数，必须区分
  "mode": "3p1d",         // 可选；不提供则在该 model+deployment+cards 下唯一确定
  "p_cards": 12,          // 可选；PD 分离时用于二次校验
  "d_cards": 4
}
```

## 匹配规则

匹配键 = `model` + `deployment` + **`cards`**（+ 可选 `mode` / `p_cards` / `d_cards`）。

1. **先按 model + deployment 过滤**，拿到候选条目。
2. **再按 cards 区分**：清单里同一 model+deployment 可能有多条（不同总卡数，例如
   `DeepSeek-V4-Flash-0731 / 独立部署` 就有 4 卡与 8 卡两套；`Qwen3.8-27B / 独立部署` 有 2 卡与 4 卡；
   `Qwen3.6-27B / 独立部署` 有 1 卡与 2 卡）。
   - `cards` 命中唯一一条 → 返回该条；
   - `cards` 命中多条（且未给 mode）→ 把这些条目的 `mode` 列出来让用户选，**不猜**；
   - `cards` 与清单都不一致 → **判不可测**，并列出「清单里该模型部署方式支持哪些卡数」（如 `1卡 / 2卡`），询问是否新增。
3. **`cards` 缺失时不允许直接命中**：必须先把该 model+deployment 支持的卡数列表返回给用户，要求补齐后再匹配。
   （否则 16 卡的 `1p1d` 会静默命中 8 卡 `1p1d` —— 这是必须避免的假命中。）
4. 命中 → 返回 `tools`、`deploy_dir`、`served_model_name`、`cards` / `p_cards` / `d_cards`、`image`，供阶段 ③ 使用。
5. 未命中 → **返回不可测结论**，明确说明「该模型/部署方式/卡数组合暂无记录」，询问是否新增（不硬测、不猜测）。

## 环境信息清单（能力确认时校验）

除「模型×部署方式」是否可测，能力确认还须校验 `../poc-orchestrator/env.local.yaml` 是否填好。按来源分三类：

| 信息 | 来源 | 缺失 / 仍为 `<...>` 时 |
| --- | --- | --- |
| 机器 IP（`env.host_31` / `env.host_32`） | 用户告知 | 反问补齐 |
| SSH 账号（`env.ssh_user`） | 用户告知 | 反问补齐 |
| 权重路径（`env.weights`） | 用户告知 | 反问补齐 |
| 工作目录（`env.workdir`） | 用户告知 | 反问补齐 |
| 通信网卡（`env.nic`） | 用户告知 | 反问补齐（多机部署必填，单机可留空） |
| 卡分配 / 端口 / 拓扑 / 镜像 / 关键参数 | 部署配置（`deploy.yaml`，由模型×部署方式决定） | 直接取用，勿重复问 |
| 容器名 | 自动生成（`poc-<部署目录名>`，见 poc-benchmark 命名约定） | 自己起，勿问 |
| 输出目录 | 自动生成 | 自己起，勿问 |

规则：
- 「用户告知」四项中任一缺失或仍是 `<...>` 占位符 → **停下来反问用户补齐**，补齐后才放行阶段 ③ 起服务 / 压测。
- 「部署配置」项来自 `deployments/*/deploy.yaml`，命中后直接读取，不再单独追问。
- `capabilities.yaml` 与 `deployments/` 属**仓库托管**：随 git 更新，本地改动会被安装覆盖；要增改请提交仓库。
- 「自动生成」项默认不打断用户。

## 输出契约

```json
{
  "supported": true,
  "model": "DeepSeek-V4-Flash-0731",
  "deployment": "PD分离",
  "cards": 16,
  "mode": "3p1d",
  "p_cards": 12,
  "d_cards": 4,
  "served_model_name": "dsv",
  "deploy_dir": "./deployments/dsv4-flash-0731-3p1d/",
  "image": { "vllm_version": "v0.27.1", "container": "poc-dsv4-flash-0731-3p1d", "image_tag": "" },
  "tools": [
    { "skill": "poc-aisbench", "modes": ["prefix_hitrate", "concurrency"] },
    { "skill": "poc-vllmbench", "modes": ["bench"] },
    { "skill": "poc-evalscope", "modes": ["longbench"] }
  ]
}
```

`supported: false` 时附带 `reason`（必须写清"该 model+deployment 支持哪些卡数"），并提示用户确认是否扩充 `capabilities.yaml` 与新增 `deployments/` 部署目录。

## 危险动作

本阶段为只读匹配，无危险动作；但「新增能力记录 / 新增部署脚本」属修改数据源，需告知用户后再写入。

## 完成判据

- [ ] 每个待测项都按 **model + deployment + cards**（+ mode）给出 可测 / 不可测 明确结论
- [ ] **没有发生卡数假命中**：`cards` 缺失时已反问，未用其他卡数的条目顶替
- [ ] 命中项已返回部署脚本位置、镜像版本、卡分配与可用工具
- [ ] `poc-orchestrator/env.local.yaml` 五类环境信息（IP / SSH 账号 / 权重路径 / 工作目录 / 通信网卡）已校验，缺失项已反问补齐
- [ ] 不可测项已向用户说明并询问，未擅自测试