// Partition + Reconnect topology simulation
//
// Star Relay base with network partition during a configurable window.
// Partitioned peers cannot communicate with the relay during the partition.
// After reconnect, convergence should be achieved.

///|
fn is_partitioned(peer_idx : Int, partitioned_peers : Array[Int]) -> Bool {
  for p in partitioned_peers {
    if p == peer_idx {
      return true
    }
  }
  false
}

///|
pub fn run_partition(config : PartitionConfig, seed : Int) -> SimResult {
  let rng = Rng::new(seed)
  let ns = config.base.namespaces
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
    let in_partition = tick >= config.partition_at_tick &&
      tick < config.reconnect_at_tick
    // 1. Write phase
    if tick < write_ticks && tick % config.base.write_interval == 0 {
      for i in 0..<n {
        let node = nodes[i]
        let ts = tick.to_double()
        for nsi in ns {
          let val = rng.next_bound(1000)
          node.store.set(nsi, node.id, val, ts, node.id)
        }
      }
    }
    // 2. Upload: skip partitioned peers during partition
    for i in 0..<n {
      if in_partition && is_partitioned(i, config.partitioned_peers) {
        continue
      }
      upload_pipes[i].send_snapshot(tick, nodes[i].store, ns)
      tick_messages += 1
    }
    // 3. Deliver uploads to relay
    for i in 0..<n {
      if in_partition && is_partitioned(i, config.partitioned_peers) {
        continue
      }
      ignore(upload_pipes[i].receive(tick, relay))
    }
    // 4. Download: skip partitioned peers during partition
    for i in 0..<n {
      if in_partition && is_partitioned(i, config.partitioned_peers) {
        continue
      }
      download_pipes[i].send_snapshot(tick, relay, ns)
      tick_messages += 1
    }
    // 5. Deliver downloads to peers
    for i in 0..<n {
      if in_partition && is_partitioned(i, config.partitioned_peers) {
        continue
      }
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
  { topology_name: "partition", convergence_tick, total_messages, per_tick }
}
