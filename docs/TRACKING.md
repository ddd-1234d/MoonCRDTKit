# MoonCRDTKit 公开开发追踪

本文件用于记录比赛阶段的公开开发线索，便于后续在 GitHub / GitLink 上对应提交、工单和合并请求。

## 已完成

- 初始化 MoonBit 包结构和项目元信息。
- 建立向量时钟和 LWW 寄存器。
- 建立 G-Counter、PN-Counter 和 OR-Set。
- 建立变更日志和副本同步摘要。
- 建立 CLI、CI、Issue 模板、PR 模板和变更记录。
- 补充与 `mizchi/crdt_db`、`mizchi/converge` 和 MoonBit 官方 CRDT 文章的差异说明。
- 增加 DeltaBatch 与 SyncPlan，形成轻量增量同步示例。

## 建议创建的工单

- `feature: 增加 MV-Register 多值寄存器`
- `feature: 增加 Map CRDT 组合对象`
- `test: 增加随机合并一致性测试`
- `docs: 增加离线表单同步示例`
- `benchmark: 增加不同副本规模下的合并性能记录`

## 建议维护节奏

- 每次新增公开 API 后同步补测试。
- 每个阶段至少更新一次 `CHANGELOG.md`。
- 比赛报名或阶段检查前，手动同步 GitHub 与 GitLink。
