# Changelog

## 0.2.0 - 2026-07-20

- Added `ReplicaState`, a cohesive offline-first state model for counters, tasks, causal clocks and operation logs.
- Made OR-Set add identity replica-scoped with `add_from`, preventing concurrent replicas from colliding on the same local sequence number.
- Made `SyncPlan` compare complete replica state instead of only aggregate counters, preventing equal-count divergent states from being skipped.
- Added merge-law, same-count divergence and out-of-order synchronization regression coverage.
- Added reproducible installation instructions and a full CI quality gate for format, metadata, check, build and tests.

## 0.1.1 - 2026-06-14

- 补充与 `mizchi/crdt_db`、`mizchi/converge` 和 MoonBit 官方 CRDT 文章的关系说明。
- 增加 `DeltaBatch`，支持根据向量时钟提取缺失变更并幂等应用。
- 增加 `SyncPlan`，支持根据同步摘要判断 push / pull / 双向交换。
- 更新 CLI 演示和测试，覆盖增量同步与摘要交换路径。

## 0.1.0 - 2026-06-12

- 初始化 MoonCRDTKit 项目结构和元信息。
- 增加 VectorClock、LwwRegister、GCounter、PNCounter、ORSet、ChangeLog 和 SyncSummary。
- 增加离线合并 CLI 演示。
- 增加 GitHub Actions、Issue 模板和 PR 模板。
- 增加 README、路线图、公开开发追踪和示例文档。
