# MoonCRDTKit 与已有 MoonBit CRDT 工作的关系

## 背景

本项目需要说明与 MoonBit 生态中已有 CRDT 工作的关系，尤其是：

- `mizchi/crdt_db@0.1.1`
- MoonBit 官方博客《Implementing CRDT Algorithms with MoonBit and Building Real-time Collaborative Applications》

## 与 mizchi/crdt_db / mizchi/converge 的关系

`mizchi/converge` 是 EG-Walker inspired Local-First DB Sync Engine。它公开说明中包含 Durable Layer、Ephemeral Layer、Event Graph、Lamport timestamp、operation log、sync protocol、WASM/JS exports、BFT adapter、Cloudflare Workers / Deno Deploy 后端建议等模块。

MoonCRDTKit 不做数据库同步引擎，也不做 EG-Walker 事件图系统。它不包含：

- 数据库 CRUD API
- Event DAG / LCA / frontiers
- operation log RLE 压缩
- HTTP / WebSocket sync transport
- WASM Component Model 接口
- Cloudflare Workers 或 Deno Deploy 适配
- BFT 签名验证层

MoonCRDTKit 的边界更小：它只提供状态型 CRDT 原语，包括 VectorClock、LWW Register、G-Counter、PN-Counter、OR-Set、ChangeLog、DeltaBatch、SyncSummary 和 SyncPlan。目标是让 MoonBit 使用者能以较低成本理解、测试和复用这些基本结构。

## 与 MoonBit 官方 CRDT 文章的关系

MoonBit 官方 CRDT 文章主要介绍协同编辑算法演进：OT、RGA、EG-Walker 和 Lomo，并展示如何构建简单的离线协同编辑应用。文章重点是协同文本编辑和事件图式合并思路。

MoonCRDTKit 不做文本 CRDT，不实现 RGA，也不实现 EG-Walker 或 Lomo。项目的重点是表单字段、计数器、集合、状态摘要这类非文本应用状态。

## MoonCRDTKit 的独立价值

1. 更适合作为 CRDT 入门和教学库：每个结构都可以单独测试和讲解。
2. 更适合轻量状态同步：离线表单、边缘设备状态、任务集合、简单计数器。
3. 更适合作为其他项目的底层积木：上层可以自己选择存储、网络和同步协议。
4. 更容易维护和扩展：后续可以逐步增加 MV-Register、Map CRDT、Delta CRDT 和随机合并一致性测试。

## 后续整改方向

- 在申报书中补充“参考说明”和“差异说明”。
- README 保留与已有项目的关系说明。
- 后续路线优先补 Map CRDT、Delta 合并和随机一致性测试，进一步强化基础库定位。
