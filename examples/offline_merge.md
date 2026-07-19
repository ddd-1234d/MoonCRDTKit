# Offline Merge Example

目标：模拟两个副本离线修改后恢复连接，最终合并为同一个可解释状态。

```moonbit nocheck
let phone = @MoonCRDTKit.ReplicaState::new(1)
let laptop = @MoonCRDTKit.ReplicaState::new(2)

phone.add_task("draft")
phone.increment(amount=8)
laptop.add_task("review")
laptop.decrement(amount=3)

let merged = phone.merge(laptop)
println(merged.clock.get(1))
println(merged.clock.get(2))
println(merged.counter.value())
println(merged.tasks.contains("draft"))
println(merged.tasks.contains("review"))
```

示例输出：

```text
1
1
5
true
true
```

每次 `ReplicaState` 变更都会分配副本内递增序号。任务添加的 OR-Set 身份由 `(replica, sequence)` 构成，因此两个副本即使各自执行第一条操作，也不会发生 Dot 冲突。合并操作满足交换律、结合律和幂等性；仓库测试同时覆盖了重复投递和乱序增量日志的收敛行为。
