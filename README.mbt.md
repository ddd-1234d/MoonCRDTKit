# MoonCRDTKit

MoonCRDTKit 是一个面向 MoonBit 的离线协同 CRDT 状态合并基础库。

项目聚焦弱网与离线场景下的多端状态收敛，提供向量时钟、LWW 寄存器、G-Counter、PN-Counter、OR-Set、变更日志和同步摘要等能力，适合协作文档、离线表单、边缘设备状态同步、多人编辑器和教学算法示例。

## 创新点

- 离线优先：副本可以先在本地修改状态，恢复连接后再合并。
- 无中心合并：不依赖服务端仲裁，多个副本按同一规则收敛。
- 因果可解释：向量时钟和变更日志记录状态来源，便于同步调试。
- 组合式 CRDT：寄存器、计数器、集合和摘要可以组合成应用状态。
- 增量同步积木：提供 `DeltaBatch` 与 `SyncPlan`，便于上层协议判断是否需要交换状态。

## 与已有 MoonBit CRDT 工作的关系

MoonCRDTKit 不是对 `mizchi/crdt_db` 或 `mizchi/converge` 的重复实现。`mizchi/converge` 更接近 EG-Walker inspired Local-First DB Sync Engine，关注数据库同步、事件图、operation log、WASM/JS SDK 和后端同步部署。MoonCRDTKit 的边界更小：只做状态型 CRDT 原语和轻量同步辅助，不提供数据库 CRUD、网络传输、WASM Component、Cloudflare/Deno 后端或 BFT 签名层。

MoonBit 官方文章《Implementing CRDT Algorithms with MoonBit and Building Real-time Collaborative Applications》主要介绍 OT、RGA、EG-Walker、Lomo 等协同文本算法路线。MoonCRDTKit 不实现文本 CRDT，也不做 RGA/EG-Walker/Lomo 富文本编辑器；它面向离线表单、任务集合、计数器、边缘设备状态和教学示例这类非文本状态同步场景。

因此，本项目定位是 MoonBit 生态中的 CRDT 基础积木库：上层项目可以在它之上自行选择存储、网络协议和应用模型。

## 当前能力

- `VectorClock`：记录副本计数，支持 tick、merge、dominates、concurrent 判断。
- `LwwRegister`：最后写入胜出寄存器，支持时间戳和副本号确定性裁决。
- `GCounter`：只增计数器，按副本取最大值合并。
- `PNCounter`：正负计数器，支持离线增减后收敛。
- `ORSet`：观察删除集合，支持离线添加、观察后删除和合并。
- `ChangeLog`：记录副本变更事件并按事件 id 去重。
- `DeltaBatch`：根据对端向量时钟提取缺失事件，支持幂等应用。
- `SyncSummary`：输出副本同步摘要，便于 CLI、调试面板和状态心跳使用。
- `SyncPlan`：比较两个摘要，判断是否需要 push / pull / 双向交换。

## 快速示例

```moonbit nocheck
let left = @MoonCRDTKit.VectorClock::new()
let right = @MoonCRDTKit.VectorClock::new()
left.tick(1)
right.tick(2)
let merged = left.merge(right)

let counter = @MoonCRDTKit.PNCounter::new()
counter.increment(1, amount=8)
counter.decrement(2, amount=3)
let log = @MoonCRDTKit.ChangeLog::new()
ignore(log.append(@MoonCRDTKit.ChangeEvent::new(1, 1, "set", "title")))
let delta = log.delta_after(left, origin=1)

println(merged.concurrent_with(left))
println(counter.value())
println(delta.to_json())
```

运行演示：

```bash
moon run cmd/main
```

运行测试：

```bash
moon test
```

## 设计原则

1. 核心库保持后端中立，不依赖网络、数据库、浏览器或平台 API。
2. 所有合并函数都保持确定性，便于在多端同步中复现结果。
3. 用简单 MoonBit 结构体表达 CRDT 状态，优先保证教学性和可测试性。
4. 不和数据库同步引擎、协同文本编辑器绑定，避免污染基础库抽象。

## 仓库

- GitHub: <https://github.com/ddd-1234d/MoonCRDTKit>
- GitLink: <https://gitlink.org.cn/ddd123d/MoonCRDTKit.git>

更完整的竞品/参考关系说明见 [docs/RELATED_WORK.md](docs/RELATED_WORK.md)。
