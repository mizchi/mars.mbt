// Topology simulation types
// Self-contained: includes inlined LWW store, Rng, NetPipe

///|
let tick_ms = 16

// --- Inlined LWW EphemeralStore ---

///|
pub(all) struct EphemeralEntry {
  value : Int
  timestamp : Double
  peer : String
} derive(Show, Eq)

///|
pub(all) struct EphemeralStore {
  data : Map[String, Map[String, EphemeralEntry]]
}

///|
pub fn EphemeralStore::new() -> EphemeralStore {
  { data: Map::new() }
}

///|
fn EphemeralStore::get_or_create_ns(
  self : EphemeralStore,
  ns : String,
) -> Map[String, EphemeralEntry] {
  match self.data.get(ns) {
    Some(m) => m
    None => {
      let m : Map[String, EphemeralEntry] = Map::new()
      self.data[ns] = m
      m
    }
  }
}

///|
pub fn EphemeralStore::set(
  self : EphemeralStore,
  ns : String,
  key : String,
  value : Int,
  timestamp : Double,
  peer : String,
) -> Unit {
  let ns_map = self.get_or_create_ns(ns)
  ns_map[key] = { value, timestamp, peer }
}

///|
pub fn EphemeralStore::get(
  self : EphemeralStore,
  ns : String,
  key : String,
) -> EphemeralEntry? {
  match self.data.get(ns) {
    Some(ns_map) => ns_map.get(key)
    None => None
  }
}

///|
pub fn EphemeralStore::get_all(
  self : EphemeralStore,
  ns : String,
) -> Map[String, EphemeralEntry] {
  match self.data.get(ns) {
    Some(ns_map) => ns_map
    None => Map::new()
  }
}

///|
/// LWW merge: higher timestamp wins, ties broken by lexicographic peer
pub fn EphemeralStore::merge(
  self : EphemeralStore,
  ns : String,
  key : String,
  remote : EphemeralEntry,
) -> Bool {
  let ns_map = self.get_or_create_ns(ns)
  match ns_map.get(key) {
    None => {
      ns_map[key] = remote
      true
    }
    Some(current) =>
      if remote.timestamp > current.timestamp {
        ns_map[key] = remote
        true
      } else if remote.timestamp == current.timestamp &&
        remote.peer > current.peer {
        ns_map[key] = remote
        true
      } else {
        false
      }
  }
}

// --- Simulation config types ---

///|
pub(all) struct PingConfig {
  ping_ms : Int
  count : Int
}

///|
pub(all) struct SimConfig {
  num_peers : Int
  ticks : Int
  ping_config : Array[PingConfig]
  write_interval : Int
  namespaces : Array[String]
}

///|
pub(all) struct GossipConfig {
  base : SimConfig
  fanout : Int
  max_hops : Int
}

///|
pub(all) struct FilteredStarConfig {
  base : SimConfig
  subscriptions : Map[Int, Array[String]]
}

///|
pub(all) struct PartitionConfig {
  base : SimConfig
  partition_at_tick : Int
  reconnect_at_tick : Int
  partitioned_peers : Array[Int]
}

///|
pub(all) struct TickMetrics {
  tick : Int
  total_messages_sent : Int
  inconsistent_pairs : Int
  total_entries : Int
} derive(Show)

///|
pub(all) struct SimResult {
  topology_name : String
  convergence_tick : Int
  total_messages : Int
  per_tick : Array[TickMetrics]
} derive(Show)

///|
pub(all) struct SimNode {
  id : String
  store : EphemeralStore
}

///|
pub fn SimNode::new(id : String) -> SimNode {
  { id, store: EphemeralStore::new() }
}

// --- Xorshift32 PRNG ---

///|
pub(all) struct Rng {
  mut state : Int
}

///|
pub fn Rng::new(seed : Int) -> Rng {
  { state: if seed == 0 { 1 } else { seed } }
}

///|
pub fn Rng::next(self : Rng) -> Int {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
pub fn Rng::next_bound(self : Rng, bound : Int) -> Int {
  self.next() % bound
}

// --- One-way network pipe ---

///|
struct InFlightPacket {
  arrival_tick : Int
  entries : Array[(String, String, EphemeralEntry)]
}

///|
pub(all) struct NetPipe {
  delay_ticks : Int
  queue : Array[InFlightPacket]
}

///|
pub fn NetPipe::new(ping_ms : Int) -> NetPipe {
  let delay = ping_ms / 2 / tick_ms
  let delay = if ping_ms > 0 && delay == 0 { 1 } else { delay }
  { delay_ticks: delay, queue: [] }
}

///|
pub fn NetPipe::send_entries(
  self : NetPipe,
  current_tick : Int,
  entries : Array[(String, String, EphemeralEntry)],
) -> Unit {
  if entries.length() > 0 {
    self.queue.push({ arrival_tick: current_tick + self.delay_ticks, entries })
  }
}

///|
pub fn NetPipe::send_snapshot(
  self : NetPipe,
  current_tick : Int,
  src : EphemeralStore,
  namespaces : Array[String],
) -> Unit {
  let entries : Array[(String, String, EphemeralEntry)] = []
  for ns in namespaces {
    let ns_entries = src.get_all(ns)
    for key, entry in ns_entries {
      entries.push((ns, key, entry))
    }
  }
  self.send_entries(current_tick, entries)
}

///|
pub fn NetPipe::receive(
  self : NetPipe,
  current_tick : Int,
  dst : EphemeralStore,
) -> Int {
  let mut merged = 0
  let remaining : Array[InFlightPacket] = []
  for pkt in self.queue {
    if pkt.arrival_tick <= current_tick {
      for entry in pkt.entries {
        let (ns, key, e) = entry
        if dst.merge(ns, key, e) {
          merged += 1
        }
      }
    } else {
      remaining.push(pkt)
    }
  }
  self.queue.clear()
  for p in remaining {
    self.queue.push(p)
  }
  merged
}
