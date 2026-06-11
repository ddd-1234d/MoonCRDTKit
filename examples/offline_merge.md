# Offline Merge Example

目标：模拟两个副本离线修改后恢复连接，最终合并为同一个可解释状态。

```moonbit nocheck
let left_clock = @MoonCRDTKit.VectorClock::new()
let right_clock = @MoonCRDTKit.VectorClock::new()
left_clock.tick(1)
right_clock.tick(2)

let merged_clock = left_clock.merge(right_clock)
let counter = @MoonCRDTKit.PNCounter::new()
counter.increment(1, amount=8)
counter.decrement(2, amount=3)

println(merged_clock.get(1))
println(merged_clock.get(2))
println(counter.value())
```

示例输出：

```text
1
1
5
```
