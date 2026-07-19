///|
pub(all) struct ClockEntry {
  replica : Int
  counter : Int
} derive(Debug, Eq)

///|
pub(all) struct VectorClock {
  entries : Array[ClockEntry]
} derive(Debug)

///|
pub(all) struct LwwRegister {
  value : String
  timestamp : Int
  replica : Int
} derive(Debug, Eq)

///|
pub(all) struct CounterEntry {
  replica : Int
  value : Int
} derive(Debug, Eq)

///|
pub(all) struct GCounter {
  entries : Array[CounterEntry]
} derive(Debug)

///|
pub(all) struct PNCounter {
  positive : GCounter
  negative : GCounter
} derive(Debug)

///|
pub(all) struct ORSetEntry {
  element : String
  replica : Int
  dot : Int
  removed : Bool
} derive(Debug, Eq)

///|
pub(all) struct ORSet {
  entries : Array[ORSetEntry]
} derive(Debug)

///|
pub(all) struct ChangeEvent {
  replica : Int
  sequence : Int
  kind : String
  target : String
} derive(Debug, Eq)

///|
pub(all) struct ChangeLog {
  events : Array[ChangeEvent]
} derive(Debug)

///|
pub(all) struct DeltaBatch {
  origin : Int
  events : Array[ChangeEvent]
} derive(Debug)

///|
pub(all) struct SyncSummary {
  replica : Int
  clock : VectorClock
  counter : PNCounter
  set : ORSet
  log : ChangeLog
  clock_entries : Int
  counter_value : Int
  set_size : Int
  log_events : Int
} derive(Debug)

///|
/// A complete, mergeable replica state for offline task and counter workloads.
pub(all) struct ReplicaState {
  replica : Int
  clock : VectorClock
  counter : PNCounter
  tasks : ORSet
  log : ChangeLog
} derive(Debug)

///|
pub(all) struct SyncPlan {
  source : Int
  target : Int
  needs_push : Bool
  needs_pull : Bool
  source_events : Int
  target_events : Int
} derive(Debug, Eq)

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn ClockEntry::new(replica : Int, counter : Int) -> ClockEntry {
  { replica, counter: max_int(counter, 0) }
}

///|
pub fn VectorClock::new() -> VectorClock {
  { entries: [] }
}

///|
pub fn VectorClock::get(self : VectorClock, replica : Int) -> Int {
  for entry in self.entries {
    if entry.replica == replica {
      return entry.counter
    }
  }
  0
}

///|
pub fn VectorClock::set(
  self : VectorClock,
  replica : Int,
  counter : Int,
) -> Unit {
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].replica == replica {
      self.entries[i] = ClockEntry::new(replica, counter)
      return
    }
  }
  self.entries.push(ClockEntry::new(replica, counter))
}

///|
pub fn VectorClock::tick(self : VectorClock, replica : Int) -> Unit {
  self.set(replica, self.get(replica) + 1)
}

///|
pub fn VectorClock::merge(
  self : VectorClock,
  other : VectorClock,
) -> VectorClock {
  let merged = VectorClock::new()
  for entry in self.entries {
    merged.set(entry.replica, entry.counter)
  }
  for entry in other.entries {
    merged.set(entry.replica, max_int(merged.get(entry.replica), entry.counter))
  }
  merged
}

///|
pub fn VectorClock::dominates(self : VectorClock, other : VectorClock) -> Bool {
  for entry in other.entries {
    if self.get(entry.replica) < entry.counter {
      return false
    }
  }
  true
}

///|
pub fn VectorClock::concurrent_with(
  self : VectorClock,
  other : VectorClock,
) -> Bool {
  !self.dominates(other) && !other.dominates(self)
}

///|
pub fn LwwRegister::new(
  value : String,
  timestamp : Int,
  replica : Int,
) -> LwwRegister {
  { value, timestamp, replica }
}

///|
pub fn LwwRegister::assign(
  self : LwwRegister,
  value : String,
  timestamp : Int,
  replica : Int,
) -> LwwRegister {
  self.merge(LwwRegister::new(value, timestamp, replica))
}

///|
pub fn LwwRegister::merge(
  self : LwwRegister,
  other : LwwRegister,
) -> LwwRegister {
  if other.timestamp > self.timestamp ||
    (other.timestamp == self.timestamp && other.replica > self.replica) {
    other
  } else {
    self
  }
}

///|
pub fn LwwRegister::to_json(self : LwwRegister) -> String {
  "{\"value\":\"\{self.value}\",\"timestamp\":\{self.timestamp},\"replica\":\{self.replica}}"
}

///|
pub fn CounterEntry::new(replica : Int, value : Int) -> CounterEntry {
  { replica, value: max_int(value, 0) }
}

///|
pub fn GCounter::new() -> GCounter {
  { entries: [] }
}

///|
pub fn GCounter::get(self : GCounter, replica : Int) -> Int {
  for entry in self.entries {
    if entry.replica == replica {
      return entry.value
    }
  }
  0
}

///|
pub fn GCounter::set(self : GCounter, replica : Int, value : Int) -> Unit {
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].replica == replica {
      self.entries[i] = CounterEntry::new(replica, value)
      return
    }
  }
  self.entries.push(CounterEntry::new(replica, value))
}

///|
pub fn GCounter::increment(
  self : GCounter,
  replica : Int,
  amount? : Int = 1,
) -> Unit {
  self.set(replica, self.get(replica) + max_int(amount, 0))
}

///|
pub fn GCounter::value(self : GCounter) -> Int {
  let mut total = 0
  for entry in self.entries {
    total = total + entry.value
  }
  total
}

///|
pub fn GCounter::merge(self : GCounter, other : GCounter) -> GCounter {
  let merged = GCounter::new()
  for entry in self.entries {
    merged.set(entry.replica, entry.value)
  }
  for entry in other.entries {
    merged.set(entry.replica, max_int(merged.get(entry.replica), entry.value))
  }
  merged
}

///|
pub fn PNCounter::new() -> PNCounter {
  { positive: GCounter::new(), negative: GCounter::new() }
}

///|
pub fn PNCounter::increment(
  self : PNCounter,
  replica : Int,
  amount? : Int = 1,
) -> Unit {
  self.positive.increment(replica, amount~)
}

///|
pub fn PNCounter::decrement(
  self : PNCounter,
  replica : Int,
  amount? : Int = 1,
) -> Unit {
  self.negative.increment(replica, amount~)
}

///|
pub fn PNCounter::value(self : PNCounter) -> Int {
  self.positive.value() - self.negative.value()
}

///|
pub fn PNCounter::merge(self : PNCounter, other : PNCounter) -> PNCounter {
  {
    positive: self.positive.merge(other.positive),
    negative: self.negative.merge(other.negative),
  }
}

///|
pub fn ORSetEntry::new(
  element : String,
  replica : Int,
  dot : Int,
  removed? : Bool = false,
) -> ORSetEntry {
  { element, replica, dot, removed }
}

///|
pub fn ORSet::new() -> ORSet {
  { entries: [] }
}

///|
fn ORSet::find_dot(self : ORSet, replica : Int, dot : Int) -> Int {
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].replica == replica && self.entries[i].dot == dot {
      return i
    }
  }
  -1
}

///|
/// Adds with an explicit replica-scoped sequence number.
/// The pair `(replica, dot)` is the identity of an observed add.
pub fn ORSet::add_from(
  self : ORSet,
  element : String,
  replica : Int,
  dot : Int,
) -> Unit {
  if self.find_dot(replica, dot) < 0 {
    self.entries.push(ORSetEntry::new(element, replica, dot))
  }
}

///|
/// Compatibility helper for single-writer sets. Multi-replica callers should use `add_from`.
pub fn ORSet::add(self : ORSet, element : String, dot : Int) -> Unit {
  self.add_from(element, 0, dot)
}

///|
pub fn ORSet::remove(self : ORSet, element : String) -> Unit {
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].element == element {
      self.entries[i] = ORSetEntry::new(
        self.entries[i].element,
        self.entries[i].replica,
        self.entries[i].dot,
        removed=true,
      )
    }
  }
}

///|
pub fn ORSet::contains(self : ORSet, element : String) -> Bool {
  for entry in self.entries {
    if entry.element == element && !entry.removed {
      return true
    }
  }
  false
}

///|
pub fn ORSet::size(self : ORSet) -> Int {
  let mut count = 0
  for entry in self.entries {
    if !entry.removed {
      count = count + 1
    }
  }
  count
}

///|
pub fn ORSet::merge(self : ORSet, other : ORSet) -> ORSet {
  let merged = ORSet::new()
  for entry in self.entries {
    merged.entries.push(entry)
  }
  for entry in other.entries {
    let index = merged.find_dot(entry.replica, entry.dot)
    if index < 0 {
      merged.entries.push(entry)
    } else if entry.removed {
      merged.entries[index] = ORSetEntry::new(
        merged.entries[index].element,
        merged.entries[index].replica,
        merged.entries[index].dot,
        removed=true,
      )
    }
  }
  merged
}

///|
pub fn ChangeEvent::new(
  replica : Int,
  sequence : Int,
  kind : String,
  target : String,
) -> ChangeEvent {
  { replica, sequence: max_int(sequence, 0), kind, target }
}

///|
pub fn ChangeEvent::id(self : ChangeEvent) -> Int {
  self.replica * 1000000 + self.sequence
}

///|
pub fn ChangeEvent::same_identity(
  self : ChangeEvent,
  other : ChangeEvent,
) -> Bool {
  self.replica == other.replica && self.sequence == other.sequence
}

///|
pub fn ChangeLog::new() -> ChangeLog {
  { events: [] }
}

///|
fn ChangeLog::contains_event(self : ChangeLog, candidate : ChangeEvent) -> Bool {
  for event in self.events {
    if event.same_identity(candidate) {
      return true
    }
  }
  false
}

///|
pub fn ChangeLog::append(self : ChangeLog, event : ChangeEvent) -> Bool {
  if self.contains_event(event) {
    false
  } else {
    self.events.push(event)
    true
  }
}

///|
pub fn ChangeLog::merge(self : ChangeLog, other : ChangeLog) -> ChangeLog {
  let merged = ChangeLog::new()
  for event in self.events {
    ignore(merged.append(event))
  }
  for event in other.events {
    ignore(merged.append(event))
  }
  merged
}

///|
pub fn ChangeLog::length(self : ChangeLog) -> Int {
  self.events.length()
}

///|
pub fn ChangeLog::delta_after(
  self : ChangeLog,
  known : VectorClock,
  origin? : Int = 0,
) -> DeltaBatch {
  let delta = DeltaBatch::new(origin)
  for event in self.events {
    if event.sequence > known.get(event.replica) {
      delta.events.push(event)
    }
  }
  delta
}

///|
pub fn ChangeLog::apply_delta(
  self : ChangeLog,
  delta : DeltaBatch,
) -> ChangeLog {
  let merged = ChangeLog::new()
  for event in self.events {
    ignore(merged.append(event))
  }
  for event in delta.events {
    ignore(merged.append(event))
  }
  merged
}

///|
pub fn DeltaBatch::new(origin : Int) -> DeltaBatch {
  { origin, events: [] }
}

///|
pub fn DeltaBatch::length(self : DeltaBatch) -> Int {
  self.events.length()
}

///|
pub fn DeltaBatch::is_empty(self : DeltaBatch) -> Bool {
  self.length() == 0
}

///|
pub fn DeltaBatch::to_json(self : DeltaBatch) -> String {
  "{\"origin\":\{self.origin},\"events\":\{self.length()}}"
}

///|
pub fn SyncSummary::new(
  replica : Int,
  clock : VectorClock,
  counter : PNCounter,
  set : ORSet,
  log : ChangeLog,
) -> SyncSummary {
  {
    replica,
    clock,
    counter,
    set,
    log,
    clock_entries: clock.entries.length(),
    counter_value: counter.value(),
    set_size: set.size(),
    log_events: log.length(),
  }
}

///|
/// Two vector clocks are equal when each causally dominates the other.
fn VectorClock::same_state(self : VectorClock, other : VectorClock) -> Bool {
  self.dominates(other) && other.dominates(self)
}

///|
/// Compares replica counters independently of entry insertion order.
fn GCounter::same_state(self : GCounter, other : GCounter) -> Bool {
  for entry in self.entries {
    if other.get(entry.replica) != entry.value {
      return false
    }
  }
  for entry in other.entries {
    if self.get(entry.replica) != entry.value {
      return false
    }
  }
  true
}

///|
/// Compares both grow-only components of a PN counter.
fn PNCounter::same_state(self : PNCounter, other : PNCounter) -> Bool {
  self.positive.same_state(other.positive) &&
  self.negative.same_state(other.negative)
}

///|
/// Finds one complete observed-add entry, including its replica-scoped identity.
fn ORSet::contains_entry(self : ORSet, candidate : ORSetEntry) -> Bool {
  for entry in self.entries {
    if entry.replica == candidate.replica &&
      entry.dot == candidate.dot &&
      entry.element == candidate.element &&
      entry.removed == candidate.removed {
      return true
    }
  }
  false
}

///|
/// Compares OR-Set state without relying on entry order or aggregate size.
fn ORSet::same_state(self : ORSet, other : ORSet) -> Bool {
  if self.entries.length() != other.entries.length() {
    return false
  }
  for entry in self.entries {
    if !other.contains_entry(entry) {
      return false
    }
  }
  true
}

///|
/// Compares operation logs by stable `(replica, sequence)` identity and payload.
fn ChangeLog::same_state(self : ChangeLog, other : ChangeLog) -> Bool {
  if self.events.length() != other.events.length() {
    return false
  }
  for event in self.events {
    let mut found = false
    for candidate in other.events {
      if event.same_identity(candidate) &&
        event.kind == candidate.kind &&
        event.target == candidate.target {
        found = true
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
/// A summary comparison uses full state, not only equal-looking aggregate counts.
fn SyncSummary::same_state(self : SyncSummary, other : SyncSummary) -> Bool {
  self.clock.same_state(other.clock) &&
  self.counter.same_state(other.counter) &&
  self.set.same_state(other.set) &&
  self.log.same_state(other.log)
}

///|
pub fn SyncSummary::to_json(self : SyncSummary) -> String {
  "{\"replica\":\{self.replica},\"clock_entries\":\{self.clock_entries},\"counter_value\":\{self.counter_value},\"set_size\":\{self.set_size},\"log_events\":\{self.log_events}}"
}

///|
pub fn SyncSummary::plan_with(
  self : SyncSummary,
  remote : SyncSummary,
) -> SyncPlan {
  let state_differs = !self.same_state(remote)
  {
    source: self.replica,
    target: remote.replica,
    needs_push: self.log_events > remote.log_events || state_differs,
    needs_pull: remote.log_events > self.log_events || state_differs,
    source_events: self.log_events,
    target_events: remote.log_events,
  }
}

///|
/// Creates an offline-first state machine whose mutations carry causal metadata.
pub fn ReplicaState::new(replica : Int) -> ReplicaState {
  {
    replica,
    clock: VectorClock::new(),
    counter: PNCounter::new(),
    tasks: ORSet::new(),
    log: ChangeLog::new(),
  }
}

///|
/// Advances local causality and returns the next local operation sequence.
fn ReplicaState::next_sequence(self : ReplicaState) -> Int {
  self.clock.tick(self.replica)
  self.clock.get(self.replica)
}

///|
/// Records a counter increment that can later be merged with an offline peer.
pub fn ReplicaState::increment(self : ReplicaState, amount? : Int = 1) -> Unit {
  let sequence = self.next_sequence()
  self.counter.increment(self.replica, amount~)
  ignore(
    self.log.append(
      ChangeEvent::new(self.replica, sequence, "increment", "counter"),
    ),
  )
}

///|
/// Records a counter decrement that can later be merged with an offline peer.
pub fn ReplicaState::decrement(self : ReplicaState, amount? : Int = 1) -> Unit {
  let sequence = self.next_sequence()
  self.counter.decrement(self.replica, amount~)
  ignore(
    self.log.append(
      ChangeEvent::new(self.replica, sequence, "decrement", "counter"),
    ),
  )
}

///|
/// Adds a task using a replica-scoped OR-Set dot, avoiding cross-replica collisions.
pub fn ReplicaState::add_task(self : ReplicaState, task : String) -> Unit {
  let sequence = self.next_sequence()
  self.tasks.add_from(task, self.replica, sequence)
  ignore(self.log.append(ChangeEvent::new(self.replica, sequence, "add", task)))
}

///|
/// Removes all adds for a task that this replica has observed.
pub fn ReplicaState::remove_task(self : ReplicaState, task : String) -> Unit {
  let sequence = self.next_sequence()
  self.tasks.remove(task)
  ignore(
    self.log.append(ChangeEvent::new(self.replica, sequence, "remove", task)),
  )
}

///|
/// Merges independently mutated replica state and operation history.
pub fn ReplicaState::merge(
  self : ReplicaState,
  other : ReplicaState,
) -> ReplicaState {
  {
    replica: self.replica,
    clock: self.clock.merge(other.clock),
    counter: self.counter.merge(other.counter),
    tasks: self.tasks.merge(other.tasks),
    log: self.log.merge(other.log),
  }
}

///|
/// Produces an exact-state sync summary for peer exchange planning.
pub fn ReplicaState::summary(self : ReplicaState) -> SyncSummary {
  SyncSummary::new(self.replica, self.clock, self.counter, self.tasks, self.log)
}

///|
pub fn SyncPlan::should_exchange(self : SyncPlan) -> Bool {
  self.needs_push || self.needs_pull
}

///|
pub fn SyncPlan::to_json(self : SyncPlan) -> String {
  "{\"source\":\{self.source},\"target\":\{self.target},\"needs_push\":\{self.needs_push},\"needs_pull\":\{self.needs_pull},\"source_events\":\{self.source_events},\"target_events\":\{self.target_events}}"
}
