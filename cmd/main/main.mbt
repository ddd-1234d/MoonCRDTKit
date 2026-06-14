///|
fn main {
  let left_clock = @crdt.VectorClock::new()
  let right_clock = @crdt.VectorClock::new()
  left_clock.tick(1)
  right_clock.tick(2)
  let merged_clock = left_clock.merge(right_clock)
  let counter = @crdt.PNCounter::new()
  counter.increment(1, amount=8)
  counter.decrement(2, amount=3)
  let tasks = @crdt.ORSet::new()
  tasks.add("offline-note", 1001)
  tasks.add("sync-later", 2001)
  let log = @crdt.ChangeLog::new()
  ignore(log.append(@crdt.ChangeEvent::new(1, 1, "add", "offline-note")))
  ignore(log.append(@crdt.ChangeEvent::new(2, 1, "add", "sync-later")))
  let summary = @crdt.SyncSummary::new(1, merged_clock, counter, tasks, log)
  let remote_summary = @crdt.SyncSummary::new(
    2,
    @crdt.VectorClock::new(),
    @crdt.PNCounter::new(),
    @crdt.ORSet::new(),
    @crdt.ChangeLog::new(),
  )
  let delta = log.delta_after(right_clock, origin=1)
  let plan = summary.plan_with(remote_summary)
  println(summary.to_json())
  println(delta.to_json())
  println(plan.to_json())
  println("counter=\{counter.value()}")
  println("tasks=\{tasks.size()}")
}
