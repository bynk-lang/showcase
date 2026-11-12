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

4. The tests. [`tests/chat/room.bynk`](tests/chat/room.bynk) drives the
   gateway by its handlers against a `TestConnection`, which records every
   frame the server sends. `message` and `close` take no route values and no
   `by`: the connection remembers them from `open`, as the platform does.

   ```bynk
   let alice = TestConnection[ServerFrame]()
   let _ <- ChatGateway.open(alice, room) by Participant(UserId.unsafe("alice"))
   let _ <- ChatGateway.message(alice, ClientFrame { text: "hi" })
   expect alice.sent() == [said("welcome"), said("hi")]
   ```

   `tc.connection()` hands over the owned `Connection` itself, so a case can
   drive the `Room` agent without the gateway. That case also checks the
   ownership rule: after `leave`, `tc.closed()` is `true`, because `remove`
   closed the connection the room held.

## Run it

```sh
bynk test .
```

The WebSocket address works at the `unit` and `integration` tiers. A `system`
case can't use it (`bynk.test.ws_needs_in_process`): a deployed WebSocket is a
real upgrade through the Worker and a Durable Object.

## Read next

- [Handle a WebSocket connection](https://bynk-lang.org/book/guides/entry-points/websocket/)
- [Testing: driving a WebSocket service](https://bynk-lang.org/book/reference/testing/#websocket-address)
- [WebSocket reference](https://bynk-lang.org/book/reference/websocket/), for
  the platform mapping and diagnostics
- Showcase: [`actors-and-authorisation`](../actors-and-authorisation/) for
  `by` and actors, and [`agent-state-machine`](../agent-state-machine/) for
  agents.
