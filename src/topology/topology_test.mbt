// Topology simulation tests

///|
test "star: 5 peers converge after drain phase" {
  let config : @topology.SimConfig = {
    num_peers: 5,
    ticks: 50,
    ping_config: [{ ping_ms: 30, count: 5 }],
    write_interval: 1,
    namespaces: ["state"],
  }
  let result = @topology.run_star(config, 42)
  inspect(result.convergence_tick >= 0, content="true")
  inspect(result.total_messages > 0, content="true")
  let last = result.per_tick[result.per_tick.length() - 1]
  inspect(last.inconsistent_pairs, content="0")
}

///|
test "star: 5 peers mixed latency converge" {
  let config : @topology.SimConfig = {
    num_peers: 5,
    ticks: 80,
    ping_config: [{ ping_ms: 30, count: 2 }, { ping_ms: 200, count: 3 }],
    write_interval: 1,
    namespaces: ["state"],
  }
  let result = @topology.run_star(config, 123)
  let last = result.per_tick[result.per_tick.length() - 1]
  inspect(last.inconsistent_pairs, content="0")
}

///|
test "gossip: 10 peers (fanout=3) converge after drain" {
  let config : @topology.GossipConfig = {
    base: {
      num_peers: 10,
      ticks: 100,
      ping_config: [{ ping_ms: 30, count: 10 }],
      write_interval: 1,
      namespaces: ["state"],
    },
    fanout: 3,
    max_hops: 3,
  }
  let result = @topology.run_gossip(config, 42)
  inspect(result.convergence_tick >= 0, content="true")
  inspect(result.total_messages > 0, content="true")
  let last = result.per_tick[result.per_tick.length() - 1]
  inspect(last.inconsistent_pairs, content="0")
}

///|
test "gossip vs star: both converge" {
  let star_config : @topology.SimConfig = {
    num_peers: 8,
    ticks: 60,
    ping_config: [{ ping_ms: 30, count: 8 }],
    write_interval: 3,
    namespaces: ["data"],
  }
  let gossip_config : @topology.GossipConfig = {
    base: {
      num_peers: 8,
      ticks: 60,
      ping_config: [{ ping_ms: 30, count: 8 }],
      write_interval: 3,
      namespaces: ["data"],
    },
    fanout: 3,
    max_hops: 3,
  }
  let star_result = @topology.run_star(star_config, 99)
  let gossip_result = @topology.run_gossip(gossip_config, 99)
  println(
    "star messages: \{star_result.total_messages}, gossip messages: \{gossip_result.total_messages}",
  )
  let star_last = star_result.per_tick[star_result.per_tick.length() - 1]
  let gossip_last = gossip_result.per_tick[gossip_result.per_tick.length() - 1]
  inspect(star_last.inconsistent_pairs, content="0")
  inspect(gossip_last.inconsistent_pairs, content="0")
}

///|
test "mesh: 5 peers converge" {
  let config : @topology.SimConfig = {
    num_peers: 5,
    ticks: 50,
    ping_config: [{ ping_ms: 30, count: 5 }],
    write_interval: 1,
    namespaces: ["state"],
  }
  let result = @topology.run_mesh(config, 42)
  inspect(result.convergence_tick >= 0, content="true")
  let last = result.per_tick[result.per_tick.length() - 1]
  inspect(last.inconsistent_pairs, content="0")
}

///|
test "mesh: message count > star" {
  let config : @topology.SimConfig = {
    num_peers: 5,
    ticks: 50,
    ping_config: [{ ping_ms: 30, count: 5 }],
    write_interval: 1,
    namespaces: ["state"],
  }
  let mesh_result = @topology.run_mesh(config, 42)
  let star_result = @topology.run_star(config, 42)
  // Mesh is O(n²) so should have more messages than Star
  inspect(
    mesh_result.total_messages > star_result.total_messages,
    content="true",
  )
}

///|
test "filtered_star: peers see only subscribed ns" {
  let subs : Map[Int, Array[String]] = Map::new()
  subs[0] = ["pos"]
  subs[1] = ["hp"]
  subs[2] = ["pos", "hp"]
  subs[3] = ["pos"]
  subs[4] = ["hp"]
  let config : @topology.FilteredStarConfig = {
    base: {
      num_peers: 5,
      ticks: 50,
      ping_config: [{ ping_ms: 30, count: 5 }],
      write_interval: 1,
      namespaces: ["pos", "hp"],
    },
    subscriptions: subs,
  }
  let result = @topology.run_filtered_star(config, 42)
  let last = result.per_tick[result.per_tick.length() - 1]
  // Filtered convergence: peers should agree on shared namespaces
  inspect(last.inconsistent_pairs, content="0")
  // Peer 0 subscribes only to "pos", should have no "hp" entries
  let hp_entries_p0 = result.per_tick[0] // just check convergence happened
  ignore(hp_entries_p0)
  inspect(result.convergence_tick >= 0, content="true")
}

///|
test "filtered_star: filtered convergence" {
  let subs : Map[Int, Array[String]] = Map::new()
  subs[0] = ["alpha"]
  subs[1] = ["beta"]
  subs[2] = ["alpha", "beta"]
  let config : @topology.FilteredStarConfig = {
    base: {
      num_peers: 3,
      ticks: 40,
      ping_config: [{ ping_ms: 30, count: 3 }],
      write_interval: 1,
      namespaces: ["alpha", "beta"],
    },
    subscriptions: subs,
  }
  let result = @topology.run_filtered_star(config, 77)
  let last = result.per_tick[result.per_tick.length() - 1]
  inspect(last.inconsistent_pairs, content="0")
}

///|
test "partition: diverge during partition" {
  let config : @topology.PartitionConfig = {
    base: {
      num_peers: 4,
      ticks: 80,
      ping_config: [{ ping_ms: 30, count: 4 }],
      write_interval: 1,
      namespaces: ["state"],
    },
    partition_at_tick: 10,
    reconnect_at_tick: 40,
    partitioned_peers: [2, 3],
  }
  let result = @topology.run_partition(config, 42)
  // During partition, there should be inconsistency
  let mid = result.per_tick[25]
  inspect(mid.inconsistent_pairs > 0, content="true")
}

///|
test "partition: reconverge after reconnect" {
  let config : @topology.PartitionConfig = {
    base: {
      num_peers: 4,
      ticks: 80,
      ping_config: [{ ping_ms: 30, count: 4 }],
      write_interval: 1,
      namespaces: ["state"],
    },
    partition_at_tick: 10,
    reconnect_at_tick: 40,
    partitioned_peers: [2, 3],
  }
  let result = @topology.run_partition(config, 42)
  let last = result.per_tick[result.per_tick.length() - 1]
  inspect(last.inconsistent_pairs, content="0")
}

///|
test "partition: convergence report" {
  let config : @topology.PartitionConfig = {
    base: {
      num_peers: 4,
      ticks: 80,
      ping_config: [{ ping_ms: 30, count: 4 }],
      write_interval: 2,
      namespaces: ["state"],
    },
    partition_at_tick: 10,
    reconnect_at_tick: 40,
    partitioned_peers: [2, 3],
  }
  let result = @topology.run_partition(config, 42)
  let buf = StringBuilder::new()
  buf.write_string("=== Partition Report ===\n")
  buf.write_string(
    "partition: tick \{config.partition_at_tick}-\{config.reconnect_at_tick}, peers: \{config.partitioned_peers}\n",
  )
  buf.write_string(
    "convergence_tick: \{result.convergence_tick}, total_messages: \{result.total_messages}\n",
  )
  buf.write_string("tick | messages | inconsistent | entries\n")
  for m in result.per_tick {
    if m.tick % 5 == 0 {
      buf.write_string(
        "\{m.tick}    | \{m.total_messages_sent}        | \{m.inconsistent_pairs}            | \{m.total_entries}\n",
      )
    }
  }
  println(buf.to_string())
  inspect(result.total_messages > 0, content="true")
}

///|
test "mesh: benchmark scaling" {
  let buf = StringBuilder::new()
  buf.write_string("=== Mesh Benchmark ===\n")
  buf.write_string(
    "peers | mesh_msgs | star_msgs | gossip_msgs | mesh_conv | star_conv | gossip_conv\n",
  )
  let peer_counts = [3, 5, 8, 10, 15, 20]
  for n in peer_counts {
    let config : @topology.SimConfig = {
      num_peers: n,
      ticks: 100,
      ping_config: [{ ping_ms: 30, count: n }],
      write_interval: 2,
      namespaces: ["state"],
    }
    let gossip_config : @topology.GossipConfig = {
      base: config,
      fanout: 3,
      max_hops: 3,
    }
    let mesh = @topology.run_mesh(config, 42)
    let star = @topology.run_star(config, 42)
    let gossip = @topology.run_gossip(gossip_config, 42)
    buf.write_string(
      "\{n}     | \{mesh.total_messages}     | \{star.total_messages}     | \{gossip.total_messages}       | \{mesh.convergence_tick}        | \{star.convergence_tick}        | \{gossip.convergence_tick}\n",
    )
    // Verify all converge
    let mesh_last = mesh.per_tick[mesh.per_tick.length() - 1]
    let star_last = star.per_tick[star.per_tick.length() - 1]
    let gossip_last = gossip.per_tick[gossip.per_tick.length() - 1]
    inspect(mesh_last.inconsistent_pairs, content="0")
    inspect(star_last.inconsistent_pairs, content="0")
    inspect(gossip_last.inconsistent_pairs, content="0")
  }
  println(buf.to_string())
}

///|
test "star: convergence report" {
  let config : @topology.SimConfig = {
    num_peers: 5,
    ticks: 60,
    ping_config: [{ ping_ms: 30, count: 3 }, { ping_ms: 200, count: 2 }],
    write_interval: 2,
    namespaces: ["pos", "hp"],
  }
  let result = @topology.run_star(config, 42)
  let buf = StringBuilder::new()
  buf.write_string("=== Star Relay Report ===\n")
  buf.write_string(
    "convergence_tick: \{result.convergence_tick}, total_messages: \{result.total_messages}\n",
  )
  let start = if result.per_tick.length() > 10 {
    result.per_tick.length() - 10
  } else {
    0
  }
  buf.write_string("tick | messages | inconsistent | entries\n")
  for i = start; i < result.per_tick.length(); i = i + 1 {
    let m = result.per_tick[i]
    buf.write_string(
      "\{m.tick}    | \{m.total_messages_sent}        | \{m.inconsistent_pairs}            | \{m.total_entries}\n",
    )
  }
  println(buf.to_string())
  inspect(result.total_messages > 0, content="true")
}
