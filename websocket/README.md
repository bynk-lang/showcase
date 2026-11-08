# WebSocket

Handling a WebSocket connection: accept it, authenticate it at the edge, hand
it to an agent, and broadcast to a room.

## The idea

A `service` bound with `from websocket(in:, out:)` names the frame types the
client sends and the server sends. Unlike an HTTP request, the connection
outlives the handler. `on open` is given an owned `Connection` and must dispose
of it, and the usual way is to transfer it into an agent that holds it. The
compiler checks that for you: a connection left undisposed is `bynk.held.leak`.

What that buys you:

- **Fail-closed authentication.** `on open` must name its actor with `by`.
  There is no anonymous upgrade, and the connection is only handed over once
  the bearer token has verified.
- **A resource you can't lose.** The connection has exactly one owner. It can
  be stored only in a `Cell` or `Map`, and `remove` closes it.
- **Parallel broadcast.** The room sends to every held connection at once, so
  one slow client can't stall the rest.

## Walkthrough

Everything lives in [`src/chat/room.bynk`](src/chat/room.bynk).

1. The actor. The upgrade is authenticated before the handler runs:

   ```bynk
   actor Participant { auth = Bearer(secret = "AUTH_SECRET"), identity = UserId }
   ```

2. The gateway. `on open` welcomes the client, then transfers the connection
   into the `Room` agent. `on message` and `on close` delegate to the same
   agent:

   ```bynk
   on open (roomId: RoomId) -> Effect[()] by user: Participant {
   	let _ <- connection.send(ServerFrame { text: "welcome" })
   	let _ <- Room(roomId).join(user.identity, connection)
   	()
   }
   ```

3. The room. It keeps each connection in a `Map` keyed by user, and
   broadcasts by sending to all of them in parallel:

   ```bynk
   on call post(sender: UserId, text: String) -> Effect[()] {
   	let _ <- conns.parTraverse((c: Connection[ServerFrame]) => c.send(ServerFrame { text: text }))
   	()
   }
   ```

## Run it

```sh
bynk check
```

This project has no `tests/` directory, on purpose. In 0.512.10 a
`from websocket` service has no address in a `bynk test` case
(`bynk.test.service_bad_address`), and a `Connection` can't be constructed in
one, so the `Room` agent can't be reached either. The compiler's own checks do
the work here: the held-connection discipline, the `by` requirement and the
open-transfer shape are all enforced by `bynk check`. On the bundle target the
generated handlers run against a `TestConnection`, as the book's guide shows,
from a TypeScript harness.

## Read next

- [Handle a WebSocket connection](https://bynk-lang.org/book/guides/entry-points/websocket/)
- [WebSocket reference](https://bynk-lang.org/book/reference/websocket/), for
  the platform mapping and diagnostics
- Showcase: [`actors-and-authorisation`](../actors-and-authorisation/) for
  `by` and actors, and [`agent-state-machine`](../agent-state-machine/) for
  agents.
