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

///|
test "or set keeps concurrent dots from different replicas" {
  let left = @MoonCRDTKit.ORSet::new()
  let right = @MoonCRDTKit.ORSet::new()
  // Both replicas legitimately issue their first local operation as sequence 1.
  left.add_from("left-task", 1, 1)
  right.add_from("right-task", 2, 1)
  let merged = left.merge(right)
  assert_true(merged.contains("left-task"))
  assert_true(merged.contains("right-task"))
  assert_eq(merged.size(), 2)
}

///|
test "crdt merges are commutative associative and idempotent" {
  let first = @MoonCRDTKit.ReplicaState::new(1)
  let second = @MoonCRDTKit.ReplicaState::new(2)
  let third = @MoonCRDTKit.ReplicaState::new(3)
  first.add_task("draft")
  first.increment(amount=2)
  second.add_task("review")
  second.decrement(amount=1)
  third.add_task("publish")

  let commutative_left = first.merge(second)
  let commutative_right = second.merge(first)
  assert_eq(commutative_left.counter.value(), commutative_right.counter.value())
  assert_eq(commutative_left.log.length(), commutative_right.log.length())
  assert_true(commutative_left.tasks.contains("draft"))
  assert_true(commutative_right.tasks.contains("review"))

  let associative_left = first.merge(second).merge(third)
  let associative_right = first.merge(second.merge(third))
  assert_eq(associative_left.counter.value(), associative_right.counter.value())
  assert_eq(associative_left.log.length(), associative_right.log.length())
  assert_eq(associative_left.tasks.size(), associative_right.tasks.size())

  let idempotent = first.merge(first)
  assert_eq(idempotent.counter.value(), first.counter.value())
  assert_eq(idempotent.log.length(), first.log.length())
  assert_eq(idempotent.tasks.size(), first.tasks.size())
}

///|
test "sync plan detects divergent states with equal aggregate statistics" {
  let left = @MoonCRDTKit.ReplicaState::new(1)
  let right = @MoonCRDTKit.ReplicaState::new(2)
  left.add_task("alpha")
  right.add_task("bravo")
  // Both summaries contain one task, one clock entry and one log event.
  let left_summary = left.summary()
  let remote = right.summary()
  assert_eq(left_summary.set_size, remote.set_size)
  assert_eq(left_summary.log_events, remote.log_events)
  let plan = left_summary.plan_with(remote)
  assert_true(plan.needs_push)
  assert_true(plan.needs_pull)
}

///|
test "out of order delta delivery converges after duplicate replay" {
  let source = @MoonCRDTKit.ReplicaState::new(7)
  source.add_task("one")
  source.add_task("two")
  source.remove_task("one")
  let empty = @MoonCRDTKit.VectorClock::new()
  let delta = source.log.delta_after(empty, origin=7)
  let target_log = @MoonCRDTKit.ChangeLog::new()
  // Deliver the last operation first, then replay the complete batch twice.
  ignore(target_log.append(delta.events[2]))
  let once = target_log.apply_delta(delta)
  let twice = once.apply_delta(delta)
  assert_eq(once.length(), 3)
  assert_eq(twice.length(), 3)
}
