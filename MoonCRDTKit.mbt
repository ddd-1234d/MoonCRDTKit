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
pub(all) struct SyncSummary {
  replica : Int
  clock_entries : Int
  counter_value : Int
  set_size : Int
  log_events : Int
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
  dot : Int,
  removed? : Bool = false,
) -> ORSetEntry {
  { element, dot, removed }
}

///|
pub fn ORSet::new() -> ORSet {
  { entries: [] }
}

///|
fn ORSet::find_dot(self : ORSet, dot : Int) -> Int {
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].dot == dot {
      return i
    }
  }
  -1
}

///|
pub fn ORSet::add(self : ORSet, element : String, dot : Int) -> Unit {
  if self.find_dot(dot) < 0 {
    self.entries.push(ORSetEntry::new(element, dot))
  }
}

///|
pub fn ORSet::remove(self : ORSet, element : String) -> Unit {
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].element == element {
      self.entries[i] = ORSetEntry::new(
        self.entries[i].element,
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
    let index = merged.find_dot(entry.dot)
    if index < 0 {
      merged.entries.push(entry)
    } else if entry.removed {
      merged.entries[index] = ORSetEntry::new(
        merged.entries[index].element,
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
pub fn ChangeLog::new() -> ChangeLog {
  { events: [] }
}

///|
fn ChangeLog::contains_id(self : ChangeLog, id : Int) -> Bool {
  for event in self.events {
    if event.id() == id {
      return true
    }
  }
  false
}

///|
pub fn ChangeLog::append(self : ChangeLog, event : ChangeEvent) -> Bool {
  if self.contains_id(event.id()) {
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
pub fn SyncSummary::new(
  replica : Int,
  clock : VectorClock,
  counter : PNCounter,
  set : ORSet,
  log : ChangeLog,
) -> SyncSummary {
  {
    replica,
    clock_entries: clock.entries.length(),
    counter_value: counter.value(),
    set_size: set.size(),
    log_events: log.length(),
  }
}

///|
pub fn SyncSummary::to_json(self : SyncSummary) -> String {
  "{\"replica\":\{self.replica},\"clock_entries\":\{self.clock_entries},\"counter_value\":\{self.counter_value},\"set_size\":\{self.set_size},\"log_events\":\{self.log_events}}"
}
