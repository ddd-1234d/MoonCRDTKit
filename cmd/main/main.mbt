///|
fn main {
  let phone = @crdt.ReplicaState::new(1)
  phone.add_task("offline-note")
  phone.increment(amount=8)
  let laptop = @crdt.ReplicaState::new(2)
  laptop.add_task("sync-later")
  laptop.decrement(amount=3)
  let summary = phone.summary()
  let remote_summary = laptop.summary()
  let merged = phone.merge(laptop)
  let delta = phone.log.delta_after(laptop.clock, origin=1)
  let plan = summary.plan_with(remote_summary)
  println(summary.to_json())
  println(delta.to_json())
  println(plan.to_json())
  println("counter=\{merged.counter.value()}")
  println("tasks=\{merged.tasks.size()}")
}
