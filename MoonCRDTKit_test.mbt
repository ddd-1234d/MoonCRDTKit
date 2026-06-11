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
