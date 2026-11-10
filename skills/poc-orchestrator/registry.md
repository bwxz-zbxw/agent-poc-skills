# POC 框架模块注册表

顶层编排器（poc-orchestrator）依据本表调度。分两层：模块（L1）+ 工具子 skill（L2）。

## L1 模块（生命周期五阶段）

| 阶段 | Skill 名 | 职责 | 关键数据源 | 状态 |
| --- | --- | --- | --- | --- |
| ① | poc-capability | 模型+部署方式能力确认 | capabilities.yaml | ✅ |
| ② | poc-case | 往期 case 检索（复用/种子参数） | cases/ 索引 | ✅ |
| ③ | poc-benchmark | 性能测试分发（含各工具子 skill） | — | ✅ |
| ④ | poc-backfill | 结果回填表格 | 列映射配置 | ✅ |
| ⑤ | poc-safety | 安全边界（横切，pre-flight 准入） | 危险操作清单 | ✅ |

## L2 工具子 skill（挂载在 poc-benchmark 下）

| Skill 名 | 测试工具 | 模式 | 触发关键词 | 指标 | 状态 |
| --- | --- | --- | --- | --- | --- |
| poc-aisbench | aisbench_auto_tools_prefix | prefix_hitrate / concurrency | 命中率、repeat_rate、并发达标 | TTFT/TPOT/吞吐/命中率 | ✅ |
| poc-vllmbench | vllm bench serve | bench | 20tps、基准、E2EL | TTFT/TPOT/E2EL/吞吐 | ✅ |
| poc-evalscope | evalscope | mmbench / longbench | MMBench、LongBench、多模态 | 评分/准确率 | ✅ |
| poc-throughput-tuning | 调参方法论 | throughput_tap / fixed_concurrency | 摸高吞吐、拐点、rr 设定 | 最优并发/rr/吞吐 | ✅ |
| （预留） | 待定 | 待定 | 新测试工具 | 待定 | 🔲 扩展位 |

## 数据源文件

| 文件 | 归属 | 用途 |
| --- | --- | --- |
| poc-capability/capabilities.yaml | 模块 ① | 可测「模型×部署方式」清单与对应工具 |
| poc-case/cases/index.yaml | 模块 ② | 往期 case 元数据索引（真实结果在用户侧） |

> 状态图例：✅ 已启用 · 🔧 开发中 · 🔲 预留扩展位。