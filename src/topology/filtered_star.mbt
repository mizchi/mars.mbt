// Topic-filtered Star Relay topology simulation
//
// Star Relay with namespace subscription filtering.
// Relay merges all namespaces, but only sends entries matching
// each peer's subscribed namespaces on download.

///|
fn send_filtered_snapshot(
  pipe : NetPipe,
  current_tick : Int,
  src : EphemeralStore,
  subscribed_ns : Array[String],
) -> Unit {
  let entries : Array[(String, String, EphemeralEntry)] = []
  for ns in subscribed_ns {
    let ns_entries = src.get_all(ns)
    for key, entry in ns_entries {
      entries.push((ns, key, entry))
    }
  }
  pipe.send_entries(current_tick, entries)
}

///|
pub fn run_filtered_star(config : FilteredStarConfig, seed : Int) -> SimResult {
  let rng = Rng::new(seed)
  let all_ns = config.base.namespaces
  let n = config.base.num_peers
  let total_ticks = config.base.ticks
  let write_ticks = total_ticks / 2
  let nodes : Array[SimNode] = []
  for i in 0..<n {
    nodes.push(SimNode::new("p\{i}"))
  }
  let relay = EphemeralStore::new()
  let upload_pipes : Array[NetPipe] = []
  let download_pipes : Array[NetPipe] = []
  for pc in config.base.ping_config {
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
  for tick in 0..<total_ticks {
    let mut tick_messages = 0
    // 1. Write phase: peers write only to their subscribed namespaces
    if tick < write_ticks && tick % config.base.write_interval == 0 {
      for i in 0..<n {
        let node = nodes[i]
        let ts = tick.to_double()
        let peer_ns = match config.subscriptions.get(i) {
          Some(subs) => subs
          None => all_ns
        }
        for nsi in peer_ns {
          let val = rng.next_bound(1000)
          node.store.set(nsi, node.id, val, ts, node.id)
        }
      }
    }
    // 2. Upload: each peer sends ALL its data to relay
    for i in 0..<n {
      upload_pipes[i].send_snapshot(tick, nodes[i].store, all_ns)
      tick_messages += 1
    }
    // 3. Deliver uploads to relay
    for i in 0..<n {
      ignore(upload_pipes[i].receive(tick, relay))
    }
    // 4. Download: relay sends only subscribed namespaces to each peer
    for i in 0..<n {
      let peer_ns = match config.subscriptions.get(i) {
        Some(subs) => subs
        None => all_ns
      }
      send_filtered_snapshot(download_pipes[i], tick, relay, peer_ns)
      tick_messages += 1
    }
    // 5. Deliver downloads to peers
    for i in 0..<n {
      ignore(download_pipes[i].receive(tick, nodes[i].store))
    }
    total_messages += tick_messages
    let inconsistent = count_filtered_inconsistent_pairs(
      nodes,
      config.subscriptions,
      all_ns,
    )
    let entries = count_total_entries(nodes, all_ns)
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
  { topology_name: "filtered_star", convergence_tick, total_messages, per_tick }
}
