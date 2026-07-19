# MoonCRDTKit

MoonCRDTKit 是面向 MoonBit 的离线协作状态合并基础库。它提供可组合的 CRDT、因果时钟、增量日志与确定性同步计划，适用于离线表单、协作任务、边缘设备状态同步等场景。

## 安装

在目标 MoonBit 项目根目录执行：

```bash
moon add ddd-1234d/MoonCRDTKit
```

然后导入包并创建本地副本：

```moonbit nocheck
import { "ddd-1234d/MoonCRDTKit" @crdt }

let phone = @crdt.ReplicaState::new(1)
phone.add_task("write offline note")
phone.increment(amount=2)

let laptop = @crdt.ReplicaState::new(2)
laptop.add_task("review merge")

let merged = phone.merge(laptop)
println(merged.summary().to_json())
```

## 验证

```bash
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all
moon run cmd/main
```

完整 API、设计边界与离线合并示例见 [README.mbt.md](README.mbt.md) 和 [examples/offline_merge.md](examples/offline_merge.md)。
