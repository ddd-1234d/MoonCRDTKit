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
