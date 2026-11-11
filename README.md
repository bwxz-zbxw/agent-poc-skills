# POC Skills

一套面向 **大模型推理 POC / 性能评测** 的模块化 Agent Skills，覆盖从「能力确认 → 案例检索 → 性能压测 → 结果回填」的完整生命周期，并用一条安全边界横切全程。

本仓库中的 skills 采用统一的 `SKILL.md` 规范（`name` + `description` frontmatter），可被多个 Agent 平台按需发现和加载。

> ⚠️ 说明：所有内网 IP、账号、权重路径等敏感信息均已脱敏为 `<...>` 占位符。安装后请按你的真实环境替换占位符（见下文「占位符清单」），否则压测/部署脚本无法直接运行。

## skill 清单

| 层级 | skill | 职责 |
| --- | --- | --- |
| L0 编排 | `poc-orchestrator` | 顶层入口，串联五阶段生命周期 |
| L1 模块 | `poc-capability` | 模型+部署方式能力确认 |
| L1 模块 | `poc-case` | 往期用例检索（复用 / 种子参数） |
| L1 模块 | `poc-benchmark` | 性能测试分发（唯一碰服务器的模块） |
| L1 模块 | `poc-backfill` | 结果回填表格 |
| L1 横切 | `poc-safety` | 安全边界 pre-flight 准入 |
| L2 工具 | `poc-aisbench` | aisbench 压测（prefix 命中率 / 并发门槛） |
| L2 工具 | `poc-vllmbench` | vllm bench serve 基准 |
| L2 工具 | `poc-evalscope` | evalscope 评测（MMBench / LongBench） |
| L2 调优 | `poc-throughput-tuning` | 吞吐摸高调参方法论 |

## 安装

### 方式一：一键脚本（推荐）

```bash
# Linux / macOS / WSL
./install.sh                # 安装到所有可用平台
./install.sh --platform trae,opencode   # 只装指定平台
./install.sh --symlink      # 用软链接，git pull 后自动生效
```

```powershell
# Windows PowerShell
.\install.ps1
.\install.ps1 -Platform trae,opencode
```

### 方式二：让 Agent 帮你装

把下面这句话发给你的 Agent（TRAE / OpenCode / Claude 等均可）：

> 把当前仓库 `skills/` 目录下的每一个子目录，复制到 `~/.agents/skills/` 下；如果我的平台是 TRAE 则复制到 `~/.trae-cn/skills/`，是 OpenCode 则复制到 `~/.config/opencode/skills/`。完成后告诉我装了哪些。

### 方式三：手动复制

把 `skills/` 下的某个 skill 目录（如 `poc-aisbench`）整个复制到目标平台的 skills 目录即可。

## 平台兼容矩阵

所有 skill 均使用 `SKILL.md`（含 `name` / `description`），各平台识别位置如下：

| 平台 | 全局 skills 目录 | 备注 |
| --- | --- | --- |
| TRAE (TraeCode) | `~/.trae-cn/skills/` | 亦可启用 `.agents` 兼容目录 |
| OpenCode | `~/.config/opencode/skills/` | 也兼容 `.agents` / `.claude` |
| Claude Code | `~/.claude/skills/` | 也兼容 `.agents` |
| 通用（.agents 规范） | `~/.agents/skills/` | 一个目录，OpenCode / Claude 均识别 |
| DSH（自研约定） | `$DSH_HOME/skills/` | 需设置 `DSH_HOME` 环境变量 |

安装脚本中的各目标目录均可用同名环境变量覆盖，例如 `TRAE_DIR=~/.my-trae/skills ./install.sh`。

## 占位符清单

机器 IP、SSH 账号、权重路径、工作目录、通信网卡集中在 `skills/poc-orchestrator/env.local.yaml` 的 `env:` 段填写（首次安装由 `env.example.yaml` 自动生成；该文件 gitignore、安装不覆盖）；其余占位符在对应文件里替换为真实值：

| 占位符 | 含义 |
| --- | --- |
| `<HOST_31>` / `<HOST_32>` | 两台推理机 IP（PD 分离双机拓扑） |
| `<HOST_EXT>` | 外部测试/办公机 IP |
| `<WEIGHTS_PATH>` | 模型权重目录（tokenizer 所在） |
| `<DSH_HOME>` | 部署脚本主目录 |
| `<AISBENCH_REPO>` | aisbench 工具仓库路径 |
| `<BENCHMARK_PATH>` / `<DATASET_PATH>` | 基准 / 数据集路径 |
| `<USER>` | 运行账号名 |
| `<SSH_USER>` | SSH 登录账号（在 `poc-orchestrator/env.local.yaml` 的 `env:` 段填写） |
| `<NIC>` | 网卡名（同上） |
| `<INTERNAL_REGISTRY>` | 内部镜像仓库地址（同上，`env.registry`） |

> 容器名不再用占位符，改为确定性命名 `poc-<部署目录名>`（例 `poc-dsv4-flash-0731-3p1d`），详见 `poc-benchmark` 的「容器命名与复用约定」：多人协作时同一「模型 × 部署方式」算出同一个容器名，可识别并复用已建容器、避免重复创建。

## 更新同步

skill 更新推送后，别人按当初的安装方式同步：

| 安装方式 | 同步命令 |
| --- | --- |
| `--symlink` 软链接 | 只 `git pull`，自动生效，无需重装（最省心） |
| 复制（默认） | `git pull` 后重跑一遍 install 脚本，自动覆盖旧目录 |
| 手动复制 / 让 Agent 复制 | 本地无 git 仓库，需重新 `git clone` 后重装一次 |

```bash
# 软链接用户（推荐）：拉一次代码即完成全部同步
git pull

# 复制安装用户：拉代码后重跑脚本覆盖
git pull && ./install.sh          # Windows 改用 .\install.ps1
```

> **覆盖策略（两类，按"是不是你的私有数据"划分）**
>
> | 类别 | 路径 | 更新行为 |
> | --- | --- | --- |
> | 🔄 **仓库托管** | `poc-capability/capabilities.yaml`、`poc-capability/deployments/`、其余全部 skill | **整目录替换**：与仓库完全一致，仓库里新增/修改/删除的部署脚本都会同步生效 |
> | 🔒 **本地私有** | `poc-orchestrator/env.local.yaml` | **永不覆盖**：你的机器 IP / SSH 账号 / 权重路径 / 网卡都在这里 |
> | 🔒 **本地数据** | `poc-case/cases/index.yaml`、`poc-case/cases/library/` | **永不覆盖**：你的历史案例库 |
>
> 也就是说：**想新增可测模型或改服务化脚本 → 改仓库并提交**（属共享知识，不该只留在你本机）；
> **机器信息 → 只写 `env.local.yaml`**（属私有配置，不进仓库、不被覆盖）。
>
> 想长期跟进更新，请优先用 `git clone` + 一键脚本安装，避免「手动复制」那种无法 `git pull` 的方式。

## 使用

以 `poc-orchestrator` 为入口：对 Agent 说「跑 POC 性能测试，我要测 <模型> + <部署方式> 的 <测试项>」，编排器会按五阶段调度各模块。若要直接压测，也可单独调用 `poc-aisbench`。

## 数据分层

仓库里**不存**任何真实单位/项目名称、人名/工号、机器 IP、内网机器名、内部 registry 域名。数据分两类：

| 类别 | 路径 | 是否入库 | 内容 |
| --- | --- | --- | --- |
| 能力清单（共享） | `poc-capability/capabilities.yaml` | ✅ 入库 | 19 种「模型 × 部署方式」组合，卡数/工具/镜像版本，全部占位符化 |
| 部署脚本（共享） | `poc-capability/deployments/<模型-部署>/` | ✅ 入库 | `start_all.sh` / `start_p.sh` / `start_d.sh` / `deploy.yaml`，IP·网卡·权重路径均为 `<...>` |
| 环境信息（本地） | `poc-orchestrator/env.local.yaml` | ❌ `.gitignore` | 机器 IP / SSH 账号 / 权重路径 / 网卡 / 镜像仓库 |
| 案例库（本地） | `poc-case/cases/` | ❌ `.gitignore`（整个目录） | 历史压测经验，`index.yaml` + `library/` |

`poc-case/cases/` 是**整目录忽略**：目录内任何文件（含将来新增的）默认都不入库，无需再补规则。该目录缺失时 `poc-case` 直接判 `none`，格式说明见 `poc-case/SKILL.md`。

新增案例或部署脚本时的**落盘门禁**：先用敏感词（单位/项目名称 / 人名 / IP / 工号）反查一遍，确认零命中后再写入。

## 当前能力覆盖（19 种模型 × 部署方式组合）

| 模型 | 部署方式 |
| --- | --- |
| DeepSeek-V4-Flash-0731 | PD分离 3p1d(16卡) / 1p1d(8卡) / 独立 dp4(4卡) / 独立 tp8(8卡) |
| DeepSeek-V4-Flash | PD分离 1p1d(8卡) |
| DeepSeek-V4.1-Flash-1017 | PD分离 1p1d(16卡) |
| DeepSeek-V4-Pro | 独立 dp2+tp8(16卡) |
| GLM-5.2 | PD分离 1p1d(16卡) / 独立 tp8(8卡) |
| GLM-5.3 | PD分离 1p1d(16卡) / 独立 tp8(8卡) |
| Qwen3.8-27B | 独立 tp2(2卡) / 独立 dp4(4卡) |
| Qwen3.6-27B | 独立 tp2(2卡) / 独立 tp1(1卡) |
| Qwen3.6-35B-A3B | 独立 tp2(2卡) |
| Qwen3.5-397B-A17B | 独立 dp4+tp2(8卡) |
| Qwen3.5-35B | 独立(2卡) |
| Minimax-M3 | PD分离 1p1d(16卡) |

硬件基线均为 650E；全部为 VLLM(vllm-ascend) 部署，历史记录均为纯文本压测。

## 许可

待定（发布前确认）。

## 目录结构

```
.
├── skills/                # 10 个 skill（每个目录一个 SKILL.md + 附属资源）
├── install.sh             # Linux/macOS/WSL 安装脚本
├── install.ps1            # Windows 安装脚本
└── README.md
```