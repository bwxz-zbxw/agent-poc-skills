---
name: "poc-capability"
description: "POC 能力确认模块：校验用户要测的「模型+部署方式」是否在能力清单已记录，有则返回可用测试工具与部署脚本（含镜像版本），无则明确告知用户并询问是否新增。当编排器进入阶段①、或需确认某模型部署方式是否可测时调用。"
---

# 能力确认模块 Skill（阶段 ①）

负责校验「模型 + 部署方式」是否在框架能力清单内。只做**匹配与告知**，不做测试执行。

## 数据源

1. `capabilities.yaml`（本目录）：可测「模型 × 部署方式」清单，每条含可用测试工具（指向 L2 子 skill）、部署脚本路径、镜像版本。
2. `deployments/<模型-部署>/`（本目录下）：该组合的**服务化启动脚本 + 镜像版本元数据**，供性能测试子 skill 查阅与实际拉起服务：
   - `start_vllm_p.sh` / `start_vllm_d.sh`：P/D 节点启动脚本
   - `deploy.yaml`：拓扑、端口、卡分配、权重路径、镜像、关键参数、测试约定

## 输入契约

```json
{ "model": "DeepSeek-V4-Flash-0731", "deployment": "PD分离", "mode": "3p1d" }
```

## 匹配规则

1. 按 `model` + `deployment`（可选 `mode`）精确匹配清单。
2. 命中 → 返回该组合可用的 `tools` 列表、`deploy_dir`（部署脚本与镜像版本位置）、`served_model_name`，供阶段 ③ 查阅/拉起服务。
3. 未命中 → **返回不可测结论，并向用户明确说明**「该模型/部署方式在当前 skill 中暂无记录」，询问是否需要新增（不硬测、不猜测）。

## 输出契约

```json
{
  "supported": true,
  "model": "DeepSeek-V4-Flash-0731",
  "deployment": "PD分离",
  "mode": "3p1d",
  "served_model_name": "dsv",
  "deploy_dir": "./deployments/dsv4-flash-0731-3p1d/",
  "tools": [
    { "skill": "poc-aisbench", "modes": ["prefix_hitrate", "concurrency"] },
    { "skill": "poc-vllmbench", "modes": ["bench"] },
    { "skill": "poc-evalscope", "modes": ["longbench"] }
  ]
}
```

`supported: false` 时附带 `reason`，并提示用户确认是否扩充 `capabilities.yaml` 与新增 `deployments/` 部署目录。

## 危险动作

本阶段为只读匹配，无危险动作；但「新增能力记录 / 新增部署脚本」属修改数据源，需告知用户后再写入。

## 完成判据

- [ ] 每个「模型×部署方式」组合都给出 可测 / 不可测 明确结论
- [ ] 命中项已返回部署脚本位置、镜像版本与可用工具
- [ ] 不可测项已向用户说明并询问，未擅自测试