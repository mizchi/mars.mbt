// Helper functions for topology simulations

///|
pub fn collect_entries(
  store : EphemeralStore,
  namespaces : Array[String]
) -> Array[(String, String, EphemeralEntry)] {
  let result : Array[(String, String, EphemeralEntry)] = []
  for ns in namespaces {
    let entries = store.get_all(ns)
    for key, entry in entries {
      result.push((ns, key, entry))
    }
  }
  result
}

///|
pub fn pick_random_targets(
  rng : Rng,
  total : Int,
  exclude : Int,
  count : Int
) -> Array[Int] {
  let targets : Array[Int] = []
  let candidates : Array[Int] = []
  for i in 0..<total {
    if i != exclude {
      candidates.push(i)
    }
  }
  let n = candidates.length()
  let pick = if count < n { count } else { n }
  for i in 0..<pick {
    let j = i + rng.next_bound(n - i)
    let tmp = candidates[i]
    candidates[i] = candidates[j]
    candidates[j] = tmp
    targets.push(candidates[i])
  }
  targets
}

///|
pub fn count_inconsistent_pairs(
  nodes : Array[SimNode],
  namespaces : Array[String]
) -> Int {
  let n = nodes.length()
  let mut inconsistent = 0
  for i in 0..<n {
    for j = i + 1; j < n; j = j + 1 {
      let mut found_diff = false
      for ns in namespaces {
        if found_diff {
          break
        }
        let entries_i = nodes[i].store.get_all(ns)
        let entries_j = nodes[j].store.get_all(ns)
        for key, ei in entries_i {
          match entries_j.get(key) {
            Some(ej) =>
              if ei.value != ej.value || ei.timestamp != ej.timestamp {
                found_diff = true
              }
            None => found_diff = true
          }
          if found_diff {
            break
          }
        }
        if not(found_diff) {
          for key, _ej in entries_j {
            match entries_i.get(key) {
              Some(_) => ()
              None => found_diff = true
            }
            if found_diff {
              break
            }
          }
        }
      }
      if found_diff {
        inconsistent += 1
      }
    }
  }
  inconsistent
}

///|
/// Count pairs of peers with inconsistent state, considering only
/// namespaces that BOTH peers subscribe to.
pub fn count_filtered_inconsistent_pairs(
  nodes : Array[SimNode],
  subscriptions : Map[Int, Array[String]],
  all_namespaces : Array[String]
) -> Int {
  let n = nodes.length()
  let mut inconsistent = 0
  for i in 0..<n {
    for j = i + 1; j < n; j = j + 1 {
      let ns_i = match subscriptions.get(i) {
        Some(subs) => subs
        None => all_namespaces
      }
      let ns_j = match subscriptions.get(j) {
        Some(subs) => subs
        None => all_namespaces
      }
      // Find common namespaces
      let common : Array[String] = []
      for nsi in ns_i {
        for nsj in ns_j {
          if nsi == nsj {
            common.push(nsi)
            break
          }
        }
      }
      if common.length() == 0 {
        continue
      }
      let mut found_diff = false
      for ns in common {
        if found_diff {
          break
        }
        let entries_i = nodes[i].store.get_all(ns)
        let entries_j = nodes[j].store.get_all(ns)
        for key, ei in entries_i {
          match entries_j.get(key) {
            Some(ej) =>
              if ei.value != ej.value || ei.timestamp != ej.timestamp {
                found_diff = true
              }
            None => found_diff = true
          }
          if found_diff {
            break
          }
        }
        if not(found_diff) {
          for key, _ej in entries_j {
            match entries_i.get(key) {
              Some(_) => ()
              None => found_diff = true
            }
            if found_diff {
              break
            }
          }
        }
      }
      if found_diff {
        inconsistent += 1
      }
    }
  }
  inconsistent
}

///|
pub fn count_total_entries(
  nodes : Array[SimNode],
  namespaces : Array[String]
) -> Int {
  let mut total = 0
  for node in nodes {
    for ns in namespaces {
      let entries = node.store.get_all(ns)
      for _key, _entry in entries {
        total += 1
      }
    }
  }
  total
}
