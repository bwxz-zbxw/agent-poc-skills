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

安装后，请将下列占位符替换为你环境的真实值：

| 占位符 | 含义 |
| --- | --- |
| `<HOST_31>` / `<HOST_32>` | 两台推理机 IP（PD 分离双机拓扑） |
| `<HOST_EXT>` | 外部测试/办公机 IP |
| `<WEIGHTS_PATH>` | 模型权重目录（tokenizer 所在） |
| `<DSH_HOME>` | 部署脚本主目录 |
| `<AISBENCH_REPO>` | aisbench 工具仓库路径 |
| `<BENCHMARK_PATH>` / `<DATASET_PATH>` | 基准 / 数据集路径 |
| `<USER>` | 运行账号名 |
| `<NIC>` | 网卡名 |
| `<CONTAINER>` | 推理服务容器名 |

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

> install 脚本每次会先删掉旧的同名 skill 目录再写入，所以「重跑」天然就是覆盖更新，不会残留旧文件。
>
> 想长期跟进更新，请优先用 `git clone` + 一键脚本安装，避免「手动复制」那种无法 `git pull` 的方式。

## 使用

以 `poc-orchestrator` 为入口：对 Agent 说「跑 POC 性能测试，我要测 <模型> + <部署方式> 的 <测试项>」，编排器会按五阶段调度各模块。若要直接压测，也可单独调用 `poc-aisbench`。

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