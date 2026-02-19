# WebSocket Echo Example

`mars` と `moonbitlang/async/websocket` を組み合わせて、
`/ws` に WebSocket echo endpoint を生やす最小サンプルです。

## Run

```bash
cd examples/websocket-echo
just run
```

サーバー起動後:

- HTTP: `http://127.0.0.1:3000/`
- WebSocket: `ws://127.0.0.1:3000/ws`

## JS fallback

`js` ターゲットでは WebSocket upgrade を行わず、`GET /ws` は
`501` (`websocket endpoint is available only on native target`) を返します。

## Test

```bash
cd examples/websocket-echo
just test
```

テストはローカルでサーバーを立ち上げ、`/ws` へ接続して
送信メッセージがそのまま返ることを確認します。
