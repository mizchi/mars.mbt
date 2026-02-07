# Topology Benchmark Results / トポロジーベンチマーク結果

## Overview / 概要

Comparison of 5 network topology patterns for ephemeral state synchronization using LWW-CRDT.
Simulated with deterministic tick-based model (16ms/tick, seed=42).

LWW-CRDT を用いたエフェメラル状態同期における 5 種類のネットワークトポロジーの比較。
決定論的 tick ベースモデル（16ms/tick, seed=42）によるシミュレーション。

## Topologies / トポロジー一覧

### Star Relay

```
  P0   P1   P2
   \   |   /
    Relay
   /   |   \
  P3   P4   P5
```

- Central relay merges all state and broadcasts to peers.
- Message complexity: **O(n)** per tick (upload + download).
- 中央リレーが全状態をマージし、各ピアへブロードキャスト。
- メッセージ量: tick あたり **O(n)**（upload + download）。

### Gossip

```
  P0 ---> P2
  P0 ---> P4
  P1 ---> P3   (fanout=k random targets)
  ...
```

- Each peer forwards to `k` random targets per tick with re-gossip on new data.
- Message complexity: **O(n * k)** per tick, with additional re-gossip rounds.
- 各ピアが tick ごとに `k` 個のランダムターゲットに送信。新データ受信時に再ゴシップ。
- メッセージ量: tick あたり **O(n * k)** + 再ゴシップ。

### Mesh (Full P2P)

```
  P0 <--> P1
  P0 <--> P2
  P1 <--> P2
  ...  (all-to-all)
```

- Every peer sends to every other peer each tick.
- Message complexity: **O(n^2)** per tick.
- No relay, no re-gossip needed.
- 全ピアが全ピアに毎 tick 送信。
- メッセージ量: tick あたり **O(n^2)**。
- リレー不要、再ゴシップ不要。

### Filtered Star

```
  P0 [pos]     P1 [hp]
       \       /
        Relay (all ns)
       /       \
  P2 [pos,hp]  P3 [pos]
```

- Star Relay with namespace subscription filtering.
- Relay merges all namespaces; download filtered per peer's subscription.
- Star Relay に namespace サブスクリプションフィルタを追加。
- リレーは全 namespace をマージ。ダウンロード時にピアの購読に応じてフィルタ。

### Partition + Reconnect

```
  tick 0-9:    [P0 P1 P2 P3] <-> Relay   (connected)
  tick 10-39:  [P0 P1] <-> Relay          (P2, P3 partitioned)
  tick 40+:    [P0 P1 P2 P3] <-> Relay   (reconnected)
```

- Star Relay with configurable network partition window.
- Partitioned peers cannot send/receive during the partition.
- Verifies convergence after reconnection.
- 設定可能なネットワーク分断ウィンドウ付き Star Relay。
- 分断中のピアは送受信不可。
- 再接続後の収束を検証。

## Benchmark: Scaling by Peer Count / ピア数によるスケーリング

Conditions / 条件:
- `ticks=100` (write phase: 0-49, drain phase: 50-99)
- `write_interval=2`, `ping_ms=30`, `namespaces=["state"]`
- Gossip: `fanout=3`, `max_hops=3`

| Peers | Mesh msgs | Star msgs | Gossip msgs | Mesh conv | Star conv | Gossip conv |
|------:|----------:|----------:|------------:|----------:|----------:|------------:|
|     3 |       600 |       600 |         750 |        50 |        50 |          50 |
|     5 |     2,000 |     1,000 |       2,058 |        50 |        50 |          50 |
|     8 |     5,600 |     1,600 |       3,558 |        50 |        50 |          50 |
|    10 |     9,000 |     2,000 |       4,491 |        50 |        50 |          50 |
|    15 |    21,000 |     3,000 |       6,774 |        50 |        50 |          51 |
|    20 |    38,000 |     4,000 |       9,051 |        50 |        50 |          52 |

### Message Growth / メッセージ増加率

| Topology | Formula          | 3 peers | 20 peers | Growth (3->20) |
|----------|------------------|--------:|---------:|---------------:|
| Star     | 2n per tick      |     600 |    4,000 |          6.7x  |
| Gossip   | ~n*k per tick    |     750 |    9,051 |         12.1x  |
| Mesh     | n*(n-1) per tick |     600 |   38,000 |         63.3x  |

## Key Observations / 主な観察結果

### Convergence Speed / 収束速度

- **Star** and **Mesh** converge immediately at tick 50 (first tick of drain phase) regardless of peer count.
  Latency is bounded by pipe delay (30ms / 2 / 16ms = 1 tick).
- **Gossip** convergence degrades slightly with scale: tick 50 at 10 peers, tick 52 at 20 peers.
  Probabilistic fanout means some peers may not receive updates in a single round.

- **Star** と **Mesh** はピア数に関係なく tick 50（drain フェーズ開始直後）で即収束。
  遅延はパイプ遅延（30ms / 2 / 16ms = 1 tick）で上界。
- **Gossip** は規模拡大で収束がわずかに遅延: 10 peers で tick 50、20 peers で tick 52。
  確率的 fanout のため、1 ラウンドで全ピアに届かない場合がある。

### Message Efficiency / メッセージ効率

- **Star** is the most efficient: linear growth `O(n)`.
- **Gossip** is moderate: roughly `O(n * fanout)` with re-gossip overhead.
- **Mesh** is the most expensive: quadratic growth `O(n^2)`, 9.5x Star at 20 peers.

- **Star** が最も効率的: 線形増加 `O(n)`。
- **Gossip** は中間: おおよそ `O(n * fanout)` + 再ゴシップのオーバーヘッド。
- **Mesh** が最もコスト高: 二次増加 `O(n^2)`、20 peers で Star の 9.5 倍。

### Partition Behavior / 分断時の挙動

- During partition (tick 10-39), partitioned peers diverge from connected peers (inconsistent_pairs > 0).
- After reconnect (tick 40+), LWW merge resolves all conflicts within 2-3 ticks.
- Convergence achieved at tick 42 (2 ticks after reconnect).

- 分断中（tick 10-39）、分断されたピアは接続中のピアと乖離（inconsistent_pairs > 0）。
- 再接続後（tick 40+）、LWW マージが 2-3 tick 以内に全コンフリクトを解決。
- tick 42 で収束達成（再接続後 2 tick）。

## When to Use Each Topology / 各トポロジーの使い分け

| Topology       | Best For                              | 適用場面                                   |
|----------------|---------------------------------------|-------------------------------------------|
| Star Relay     | General use, scalable                 | 汎用、スケーラブル                          |
| Gossip         | Decentralized, no single point of failure | 分散型、単一障害点なし                      |
| Mesh           | Small groups (<10), lowest latency    | 小規模グループ（<10）、最低遅延              |
| Filtered Star  | Topic-based pub/sub, bandwidth saving | トピックベースの pub/sub、帯域節約           |
| Partition      | Testing resilience, network simulation | 耐障害性テスト、ネットワークシミュレーション    |

## Reproducing / 再現方法

```bash
cd mars
moon test -p topology
```

All topology tests including the benchmark are in `src/topology/topology_test.mbt`.

全トポロジーテスト（ベンチマーク含む）は `src/topology/topology_test.mbt` にあります。
