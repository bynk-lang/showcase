# Testing

Tests written in Bynk itself. A box office places seat holds that lapse after
fifteen minutes. The code under test is deliberately tiny. The two suites are
the point: one tests a commons, the other drives a context's HTTP handlers with
the platform's `Clock` and `Kv` replaced by deterministic doubles, a `stub` that
moves time on, fixtures read from files, and fabricated values for refined
types.

## The idea

In Bynk, `suite`, `case`, `expect`, `stub`, `fixture` and `Val[T]` are part of
the language, not a library. The compiler knows a test from production code, so
`expect` and `Val[T]` outside a test are compile errors, and a suite's helpers
and fixtures never reach the deployable. `expect` takes the same `Bool`
predicate an `invariant` does, so there's no assertion library to learn.

Isolation comes from capabilities. A unit asks for `Clock` and `Kv` with
`given`, so a test double is just another provider at that seam. Under
`bynk test` every platform capability gets one: the clock reads the epoch, `Kv`
is an in-memory store, and each case starts fresh. When a case needs a
different answer, `stub` overrides one operation and leaves the rest alone.
The right-hand side is a value or `fails`, never a block, so a double can't
grow logic of its own.

## Walkthrough

1. [`src/holds/policy.bynk`](src/holds/policy.bynk): the rules. `Seats` is
   `Int where InRange(1, 8)`, a `HoldId` is `H-` and four digits, such as
   `H-0042`, and `isLive` says whether a hold is still inside its fifteen
   minutes.
2. [`src/holds/desk.bynk`](src/holds/desk.bynk): an HTTP service that stamps
   a hold with `Clock.now()`, stores it in `Kv`, and answers `Gone` once it
   has lapsed.
3. [`tests/holds/policy.bynk`](tests/holds/policy.bynk): the commons suite.
   Pure functions need no doubles. A helper builds a hold, using `Val` for
   the seat count because it doesn't matter, and pinning the `HoldId` because
   `Val` can't invent a string that matches a pattern:

   ```bynk
   fn placedAtEpoch() -> Hold {
   	Hold {
   		id: Val[HoldId]("H-0001"),
   		seats: Val[Seats],
   		placedAt: Instant.fromEpochMillis(0),
   	}
   }
   ```

   The cases test both sides of the fifteen-minute boundary, use `?` to unwrap
   `Seats.of(8)` (an `Err` fails the case), and decode two JSON payloads kept
   in [`fixtures/`](fixtures/), one of which breaks the seat limit:

   ```bynk
   fixture groupBooking = "fixtures/group-booking.json"
   ```

4. [`tests/holds/desk.bynk`](tests/holds/desk.bynk): the context suite,
   driving `api.POST` and `api.GET`. With no stub, a new hold is stamped at
   the epoch, a hold reads back from the in-memory `Kv`, and the next case
   finds `Kv` empty again. To test expiry, a sequenced stub gives each call to
   `Clock.now()` its own answer, the first for placing the hold and the second
   for looking it up:

   ```bynk
   stub Clock.now() returns each [Instant.fromEpochMillis(0), Instant.fromEpochMillis(0) + 15.minutes]
   ```

   Finally, `stub Kv.get(_) fails` injects a fault, and
   `expect … faults` claims it.

## Run it

```sh
bynk test .
```

To try the service by hand, run `bynk dev` and, in another terminal:

```sh
curl -X POST localhost:8787/holds -H 'content-type: application/json' -d '{"id":"H-0042","seats":2}'
curl localhost:8787/holds/H-0042
```

## Read next

- [The testing philosophy](https://bynk-lang.org/book/guides/testing/philosophy/)
- [Write tests](https://bynk-lang.org/book/guides/testing/write-tests/)
- [Run your tests](https://bynk-lang.org/book/guides/testing/run-tests/)
- [Test tiers](https://bynk-lang.org/book/guides/testing/integration/)
- [Testing reference](https://bynk-lang.org/book/reference/testing/), including
  [platform capabilities under test](https://bynk-lang.org/book/reference/testing/#platform-doubles)
- [Test fixtures](https://bynk-lang.org/book/reference/fixtures/)
- Showcase: [`capabilities-and-providers`](../capabilities-and-providers/) for
  the seams a test double plugs into, and
  [`refined-types`](../refined-types/) for the types `Val` fabricates.
