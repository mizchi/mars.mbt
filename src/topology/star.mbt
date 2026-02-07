// Star Relay topology simulation

///|
pub fn run_star(config : SimConfig, seed : Int) -> SimResult {
  let rng = Rng::new(seed)
  let ns = config.namespaces
  let n = config.num_peers
  let total_ticks = config.ticks
  let nodes : Array[SimNode] = []
  for i in 0..<n {
    nodes.push(SimNode::new("p\{i}"))
  }
  let relay = EphemeralStore::new()
  let upload_pipes : Array[NetPipe] = []
  let download_pipes : Array[NetPipe] = []
  for pc in config.ping_config {
    for _j in 0..<pc.count {
      upload_pipes.push(NetPipe::new(pc.ping_ms))
      download_pipes.push(NetPipe::new(pc.ping_ms))
    }
  }
  while upload_pipes.length() < n {
    upload_pipes.push(NetPipe::new(50))
    download_pipes.push(NetPipe::new(50))
  }
  let per_tick : Array[TickMetrics] = []
  let mut total_messages = 0
  let mut convergence_tick = -1
  let write_ticks = total_ticks / 2
  for tick in 0..<total_ticks {
    let mut tick_messages = 0
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
    for i in 0..<n {
      upload_pipes[i].send_snapshot(tick, nodes[i].store, ns)
      tick_messages += 1
    }
    for i in 0..<n {
      ignore(upload_pipes[i].receive(tick, relay))
    }
    for i in 0..<n {
      download_pipes[i].send_snapshot(tick, relay, ns)
      tick_messages += 1
    }
    for i in 0..<n {
      ignore(download_pipes[i].receive(tick, nodes[i].store))
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
  { topology_name: "star", convergence_tick, total_messages, per_tick }
}
