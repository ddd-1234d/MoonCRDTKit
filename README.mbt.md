# MoonCRDTKit

MoonCRDTKit 是一个面向 MoonBit 的离线协同 CRDT 状态合并基础库。

项目聚焦弱网与离线场景下的多端状态收敛，提供向量时钟、LWW 寄存器、G-Counter、PN-Counter、OR-Set、变更日志和同步摘要等能力，适合协作文档、离线表单、边缘设备状态同步、多人编辑器和教学算法示例。

## 创新点

- 离线优先：副本可以先在本地修改状态，恢复连接后再合并。
- 无中心合并：不依赖服务端仲裁，多个副本按同一规则收敛。
- 因果可解释：向量时钟和变更日志记录状态来源，便于同步调试。
- 组合式 CRDT：寄存器、计数器、集合和摘要可以组合成应用状态。

## 当前能力

- `VectorClock`：记录副本计数，支持 tick、merge、dominates、concurrent 判断。
- `LwwRegister`：最后写入胜出寄存器，支持时间戳和副本号确定性裁决。
- `GCounter`：只增计数器，按副本取最大值合并。
- `PNCounter`：正负计数器，支持离线增减后收敛。
- `ORSet`：观察删除集合，支持离线添加、观察后删除和合并。
- `ChangeLog`：记录副本变更事件并按事件 id 去重。
- `SyncSummary`：输出副本同步摘要，便于 CLI、调试面板和状态心跳使用。

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

println(merged.concurrent_with(left))
println(counter.value())
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

## 仓库

- GitHub: <https://github.com/ddd-1234d/MoonCRDTKit>
- GitLink: 待从 GitHub 导入后填写
