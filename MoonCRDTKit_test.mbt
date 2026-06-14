///|
test "vector clock ticks and reads replica counters" {
  let clock = @MoonCRDTKit.VectorClock::new()
  clock.tick(1)
  clock.tick(1)
  clock.tick(2)
  assert_eq(clock.get(1), 2)
  assert_eq(clock.get(2), 1)
  assert_eq(clock.get(9), 0)
}

///|
test "vector clock merges and detects concurrency" {
  let left = @MoonCRDTKit.VectorClock::new()
  let right = @MoonCRDTKit.VectorClock::new()
  left.set(1, 2)
  right.set(2, 3)
  let merged = left.merge(right)
  assert_eq(merged.get(1), 2)
  assert_eq(merged.get(2), 3)
  assert_true(left.concurrent_with(right))
  assert_true(merged.dominates(left))
}

///|
test "lww register chooses newest timestamp and deterministic replica tie" {
  let base = @MoonCRDTKit.LwwRegister::new("draft", 1, 1)
  let newer = base.assign("saved", 2, 1)
  let tie = @MoonCRDTKit.LwwRegister::new("remote", 2, 9)
  let merged = newer.merge(tie)
  assert_eq(newer.value, "saved")
  assert_eq(merged.value, "remote")
  assert_true(merged.to_json().contains("\"replica\":9"))
}

///|
test "g counter grows per replica and merges by max" {
  let left = @MoonCRDTKit.GCounter::new()
  let right = @MoonCRDTKit.GCounter::new()
  left.increment(1, amount=2)
  right.increment(1, amount=1)
  right.increment(2, amount=5)
  let merged = left.merge(right)
  assert_eq(merged.get(1), 2)
  assert_eq(merged.get(2), 5)
  assert_eq(merged.value(), 7)
}

///|
test "pn counter supports offline increments and decrements" {
  let left = @MoonCRDTKit.PNCounter::new()
  let right = @MoonCRDTKit.PNCounter::new()
  left.increment(1, amount=10)
  left.decrement(1, amount=3)
  right.increment(2, amount=4)
  right.decrement(2, amount=1)
  let merged = left.merge(right)
  assert_eq(left.value(), 7)
  assert_eq(merged.value(), 10)
}

///|
test "or set merges adds and observed removes" {
  let left = @MoonCRDTKit.ORSet::new()
  let right = @MoonCRDTKit.ORSet::new()
  left.add("task-a", 101)
  right.add("task-b", 201)
  let first = left.merge(right)
  assert_true(first.contains("task-a"))
  assert_true(first.contains("task-b"))
  first.remove("task-a")
  let second = first.merge(left)
  assert_false(second.contains("task-a"))
  assert_true(second.contains("task-b"))
  assert_eq(second.size(), 1)
}

///|
test "change logs deduplicate events by replica sequence id" {
  let left = @MoonCRDTKit.ChangeLog::new()
  let right = @MoonCRDTKit.ChangeLog::new()
  let event = @MoonCRDTKit.ChangeEvent::new(1, 7, "set", "title")
  assert_true(left.append(event))
  assert_false(left.append(event))
  assert_true(right.append(@MoonCRDTKit.ChangeEvent::new(2, 1, "add", "task")))
  let merged = left.merge(right)
  assert_eq(event.id(), 1000007)
  assert_eq(merged.length(), 2)
}

///|
test "change logs produce idempotent delta batches from vector clocks" {
  let source = @MoonCRDTKit.ChangeLog::new()
  ignore(source.append(@MoonCRDTKit.ChangeEvent::new(1, 1, "set", "title")))
  ignore(source.append(@MoonCRDTKit.ChangeEvent::new(1, 2, "set", "body")))
  ignore(source.append(@MoonCRDTKit.ChangeEvent::new(2, 1, "add", "tag")))
  let known = @MoonCRDTKit.VectorClock::new()
  known.set(1, 1)
  let delta = source.delta_after(known, origin=9)
  assert_eq(delta.origin, 9)
  assert_eq(delta.length(), 2)
  assert_false(delta.is_empty())
  assert_true(delta.to_json().contains("\"events\":2"))
  let target = @MoonCRDTKit.ChangeLog::new()
  ignore(target.append(@MoonCRDTKit.ChangeEvent::new(1, 1, "set", "title")))
  let first = target.apply_delta(delta)
  let second = first.apply_delta(delta)
  assert_eq(first.length(), 3)
  assert_eq(second.length(), 3)
}

///|
test "sync summary reports compact replica state" {
  let clock = @MoonCRDTKit.VectorClock::new()
  let counter = @MoonCRDTKit.PNCounter::new()
  let set = @MoonCRDTKit.ORSet::new()
  let log = @MoonCRDTKit.ChangeLog::new()
  clock.tick(1)
  counter.increment(1, amount=5)
  set.add("doc", 101)
  ignore(log.append(@MoonCRDTKit.ChangeEvent::new(1, 1, "add", "doc")))
  let summary = @MoonCRDTKit.SyncSummary::new(1, clock, counter, set, log)
  assert_eq(summary.clock_entries, 1)
  assert_eq(summary.counter_value, 5)
  assert_eq(summary.set_size, 1)
  assert_true(summary.to_json().contains("\"log_events\":1"))
}

///|
test "sync summaries build exchange plans" {
  let clock = @MoonCRDTKit.VectorClock::new()
  let local_counter = @MoonCRDTKit.PNCounter::new()
  let remote_counter = @MoonCRDTKit.PNCounter::new()
  let set = @MoonCRDTKit.ORSet::new()
  let local_log = @MoonCRDTKit.ChangeLog::new()
  let remote_log = @MoonCRDTKit.ChangeLog::new()
  local_counter.increment(1, amount=3)
  remote_counter.increment(1, amount=1)
  ignore(
    local_log.append(@MoonCRDTKit.ChangeEvent::new(1, 1, "inc", "counter")),
  )
  ignore(
    local_log.append(@MoonCRDTKit.ChangeEvent::new(1, 2, "inc", "counter")),
  )
  ignore(
    remote_log.append(@MoonCRDTKit.ChangeEvent::new(1, 1, "inc", "counter")),
  )
  let local_summary = @MoonCRDTKit.SyncSummary::new(
    1, clock, local_counter, set, local_log,
  )
  let remote = @MoonCRDTKit.SyncSummary::new(
    2, clock, remote_counter, set, remote_log,
  )
  let plan = local_summary.plan_with(remote)
  assert_true(plan.needs_push)
  assert_true(plan.needs_pull)
  assert_true(plan.should_exchange())
  assert_true(plan.to_json().contains("\"source\":1"))
}
