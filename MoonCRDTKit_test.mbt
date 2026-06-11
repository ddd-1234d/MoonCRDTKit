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
