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
