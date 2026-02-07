// Mesh (Full P2P) topology simulation
//
// Every peer sends to every other peer each tick (O(n²) messages).
// No re-gossip needed since all peers communicate directly.

///|
pub fn run_mesh(config : SimConfig, seed : Int) -> SimResult {
  let rng = Rng::new(seed)
  let ns = config.namespaces
  let n = config.num_peers
  let total_ticks = config.ticks
  let write_ticks = total_ticks / 2
  let nodes : Array[SimNode] = []
  for i in 0..<n {
    nodes.push(SimNode::new("p\{i}"))
  }
  // Full mesh pipes: pipes[i][j] = pipe from i to j
  let pipes : Array[Array[NetPipe]] = []
  let peer_pings : Array[Int] = []
  for pc in config.ping_config {
    for _j in 0..<pc.count {
      peer_pings.push(pc.ping_ms)
    }
  }
  while peer_pings.length() < n {
    peer_pings.push(50)
  }
  for i in 0..<n {
    let row : Array[NetPipe] = []
    for j in 0..<n {
      let avg_ping = (peer_pings[i] + peer_pings[j]) / 2
      row.push(NetPipe::new(avg_ping))
    }
    pipes.push(row)
  }
  let per_tick : Array[TickMetrics] = []
  let mut total_messages = 0
  let mut convergence_tick = -1
  for tick in 0..<total_ticks {
    let mut tick_messages = 0
    // 1. Write phase
    if tick < write_ticks && tick % config.write_interval == 0 {
      for i in 0..<n {
        let node = nodes[i]
        let ts = tick.to_double()
        for nsi in ns {
          let val = rng.next_bound(1000)
          node.store.set(nsi, node.id, val, ts, node.id)
        }
      }
    }
    // 2. Each peer sends snapshot to ALL other peers
    for i in 0..<n {
      let entries = collect_entries(nodes[i].store, ns)
      if entries.length() > 0 {
        for j in 0..<n {
          if i != j {
            pipes[i][j].send_entries(tick, entries)
            tick_messages += 1
          }
        }
      }
    }
    // 3. Deliver all
    for j in 0..<n {
      for i in 0..<n {
        if i != j {
          ignore(pipes[i][j].receive(tick, nodes[j].store))
        }
      }
    }
    total_messages += tick_messages
    let inconsistent = count_inconsistent_pairs(nodes, ns)
    let entries = count_total_entries(nodes, ns)
    per_tick.push({
      tick,
      total_messages_sent: tick_messages,
      inconsistent_pairs: inconsistent,
      total_entries: entries,
    })
    if inconsistent == 0 && convergence_tick == -1 && tick >= write_ticks {
      convergence_tick = tick
    }
  }
  { topology_name: "mesh", convergence_tick, total_messages, per_tick }
}
