---
name: "poc-backfill"
description: "POC 结果回填模块：当用户提供了待测项表格（Excel）时，按列映射把测试结果（result spec）回填进表格，输出成品。当编排器进入阶段④、或需要把测试结果写回表格时调用。"
---

# 结果回填模块 Skill（阶段 ④）

把阶段 ③（或阶段 ② 复用的）`result spec` 按映射写回用户提供的表格。**只回填，不改动原始表格结构与无关单元格**。

## 输入契约

```json
{
  "source_table": "./待测项.xlsx",
  "output_table": "./待测项_回填.xlsx",     // 默认另存新文件，不覆盖原表
  "column_mapping": {
    "ttft": "TTFT(ms)",                      // result.metrics 字段 → 表头列名
    "tpot": "TPOT(ms)",
    "throughput": "吞吐(tok/s)",
    "status": "达标",
    "concurrency": "最优并发"
  },
  "results": [ { "task_id": "task_16k_j128", "status": "pass", "metrics": { "ttft_avg": 4.2 } } ]
}
```

## 回填规则

1. **定位目标行**：按 `task_id`/场景键匹配表格中的待测项行。
2. **单位换算**：统一换算后再写（如 TTFT s→ms、吞吐 tok/s 等），在 `column_mapping` 中约定单位。
3. **达标列**：按 `thresholds` 判定 达标/未达标 写入 `status` 映射列。
4. **保留原表**：默认**另存新文件**，不覆盖原始表格；覆盖原表须经 `poc-safety` 人工确认。
5. **复用 Excel 能力**：读写 `.xlsx` 时复用 xlsx 处理能力（列定位、单元格写入、格式保留）。

## 输出契约

```json
{ "output_table": "./待测项_回填.xlsx", "filled_rows": 12, "not_found": [] }
```

`not_found` 列出未在表格中匹配到、无法回填的 task_id，需向用户说明。

## 危险动作

- 覆盖/修改**原始表格** → 必须人工确认；默认另存新文件。
- 删除原表或任何无关单元格/行 → 禁止。

## 完成判据

- [ ] 结果已按列映射回填，单位已换算
- [ ] 达标列已正确填充
- [ ] 原始表格未被覆盖（默认另存新文件）