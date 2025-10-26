# BT

bt is a library for decoding/encoding the binary "BYOND Topic" format, and two command-line tools:

- `bts` — a tiny server that maps text queries to responses (string, number, or null).
- `btc` — a client that sends a query and prints the decoded response.

## Quick start

### Prerequisites
- Zig

### Build
- Build the project: `zig build`
- Run tests: `zig build test`
- Run client: `zig build client`
- Run server: `zig build server`

## Examples

The next example runs a server that answers two queries:
- Query `?players` returns the number 5
- Query `?status` returns the string "foobar"

```console
$ bts --ip 127.0.0.1 --port 1234 "?players" 5 "?status" foobar
```

Ask the server from the client:
```console
$ btc 127.0.0.1:1234 ?status
foobar
```

CLI notes
- Client usage: `btc <HOST>:<PORT> <QUERY>`
- Server usage: `bts [--ip IP] [--port PORT] <MAPPING...>`
  - Mapping entries are pairs of `"<QUERY>" "<RESPONSE>"`.
  - If a mapping value parses as a float it is treated as a number; otherwise it is a string.
  - If no mapping matches, the server responds with `null`.
