// Gossip topology simulation

///|
priv struct GossipMessage {
  from : Int
  entries : Array[(String, String, EphemeralEntry)]
}

///|
pub fn run_gossip(config : GossipConfig, seed : Int) -> SimResult {
  let rng = Rng::new(seed)
  let ns = config.base.namespaces
  let n = config.base.num_peers
  let fanout = config.fanout
  let max_hops = config.max_hops
  let total_ticks = config.base.ticks
  let write_ticks = total_ticks / 2
  let nodes : Array[SimNode] = []
  for i in 0..<n {
    nodes.push(SimNode::new("p\{i}"))
  }
  let pipes : Array[Array[NetPipe]] = []
  let peer_pings : Array[Int] = []
  for pc in config.base.ping_config {
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
    for i in 0..<n {
      let entries = collect_entries(nodes[i].store, ns)
      if entries.length() > 0 {
        let targets = pick_random_targets(rng, n, i, fanout)
        for t in targets {
          pipes[i][t].send_entries(tick, entries)
          tick_messages += 1
        }
      }
    }
    for _round in 0..<max_hops {
      let re_gossip : Array[GossipMessage] = []
      for j in 0..<n {
        let mut any_new = false
        for i in 0..<n {
          if i == j {
            continue
          }
          let merged = pipes[i][j].receive(tick, nodes[j].store)
          if merged > 0 {
            any_new = true
          }
        }
        if any_new {
          let entries = collect_entries(nodes[j].store, ns)
          re_gossip.push({ from: j, entries })
        }
      }
      if re_gossip.length() == 0 {
        break
      }
      for msg in re_gossip {
        let targets = pick_random_targets(rng, n, msg.from, fanout)
        for t in targets {
          pipes[msg.from][t].send_entries(tick, msg.entries)
          tick_messages += 1
        }
      }
    }
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
  {
    topology_name: "gossip",
    convergence_tick,
    total_messages,
    per_tick,
  }
}
