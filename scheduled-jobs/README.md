# Scheduled jobs

An uptime monitor driven by two cron schedules. Every five minutes it probes
each watched URL with `Fetch`, all at once and each with a time limit, and
records what it found. At 03:00 each day it stops watching any target that
hasn't answered healthily for a day. A small HTTP service lets an operator add
targets and anyone read them back, and the tests fire both schedules at chosen
virtual times.

## The idea

A cron handler is an entry point like an HTTP route, declared as
`on schedule("…")` in a `service … from cron`. It has no caller and no
principal. If the handler wants to know when it fired, it declares one `Int`
parameter and receives the *scheduled* fire time in epoch milliseconds. That
instant is aligned to the schedule, so a run that starts late still measures
from the same moment. It also makes a handler easy to test: a case passes
whatever time it likes.

The handler returns `Effect[Result[(), E]]`. There is no retry, so `Err` is just
logged. The useful question is which outcomes count as failures at all. Here an
upstream that is down, or too slow to answer, is data to record, not a failed
run.

A run also has a time limit, so one hanging target mustn't hold up the rest.
The probes go out together with `parTraverse`, and each is bounded with
`within(ProbeBudget)`.

## Walkthrough

[`src/uptime/policy.bynk`](src/uptime/policy.bynk) is the pure policy: what
counts as healthy, and when a quiet target is abandoned.

```bynk
fn isAbandoned(seenUp: Instant, now: Instant) -> Bool {
	now - seenUp >= GiveUpAfter
}
```

[`src/uptime/monitor.bynk`](src/uptime/monitor.bynk) holds the `Watchlist`
agent, a `Map` of targets, and the `jobs` service with its two schedules. Each
handler turns `at` into an `Instant` before doing anything else. `within` wraps
the probe's own `Result` in another, so a `FetchError` and a timeout both become
a recorded `Unreachable`:

```bynk
let probe = match res {
	Ok(Ok(r)) => Answered(r.status),
	Ok(Err(_)) => Unreachable,
	Err(TimedOut { .. }) => Unreachable,
}
```

The sweep measures its cut-off from the scheduled time:

```bynk
on schedule("0 3 * * *") (at: Int) -> Effect[Result[(), String]] given Logger {
	let gone <- Watchlist(Everything).retire(Instant.fromEpochMillis(at))
```

Because the cron fetches whatever URL it is given, `POST /targets` is guarded by
an `Operator` actor (a verified bearer token), and the agent's `add` refuses a
name it already watches, so the route answers `Conflict` rather than replacing
a target or resetting its `seenUp`. To fix a wrong URL, an operator removes the
target with `DELETE /targets/:name` and adds it again.

`parTraverse` starts every probe at once, and each records its own result, so
the doc comment on the probe notes what to change before watching hundreds of
targets.

[`tests/uptime/monitor.bynk`](tests/uptime/monitor.bynk) is the unit suite. It
fires each schedule with `jobs.schedule("<expr>", at)`, stubs what the upstream
answers, and reads the effect back over HTTP. It covers a healthy answer, an
upstream that is down, an empty watchlist (no request is sent), a 5xx that
doesn't count as a sign of life, a duplicate name, and a URL that only *contains*
`https://`:

```bynk
stub Fetch.send(_) returns Err(Network)
let _ <- api.POST("/targets", NewTarget {
	name: "shop",
	url: "https://shop.test",
}) by Operator("ops")
let r <- jobs.schedule("*/5 * * * *", 300000)
expect r is Ok(_)
```

One case stubs a target that `never` answers next to a healthy one. Stub
latency runs on virtual time, so the `ProbeBudget` passes without the test
sleeping. The hanging target is recorded as `Unreachable` and the healthy one
as `Answered(200)`.

[`tests/uptime/sweep.bynk`](tests/uptime/sweep.bynk) runs `as system`, so the
schedule fires through the Worker's real `scheduled` entry point. A `stub` isn't
allowed there, so it drives only the sweep, plus one `by Nobody` case showing
the auth seam refuse an anonymous `POST` and `DELETE`. `advance Clock` stamps two targets
five minutes apart, and one sweep at 03:00 the next day lands on either side of
the one-day boundary:

```bynk
// 03:00 on day 1: exactly a day after `blog` was added, five minutes short for `shop`
let r <- jobs.schedule("0 3 * * *", 97200000)
```

Every `at` in the tests is an instant its schedule really fires at, so the
cases read like real runs.

## Run it

```sh
bynkc test .
bynk dev
```

With `bynk dev` running, `POST /targets` with `{"name": "…", "url": "https://…"}`
and an `Authorization: Bearer <jwt>` header signed with `OPS_JWT_SECRET` starts
watching a URL, and `GET /targets/<name>` reads it back. Its last probe
reads `Unchecked` until the five-minute schedule has run.

## Read next

- [Run a task on a schedule](https://bynk-lang.org/book/guides/entry-points/cron/)
- [Cron reference](https://bynk-lang.org/book/reference/cron/): the handler
  form and its rules.
- [Cron and queue at `system`](https://bynk-lang.org/book/reference/testing/#cron-queue-system)
- [Run independent calls at the same time](https://bynk-lang.org/book/guides/effects-and-capabilities/run-independent-calls-at-the-same-time/)
- [Bound how long a call may take](https://bynk-lang.org/book/guides/effects-and-capabilities/bound-how-long-a-call-may-take/)
- [Platform capabilities under test](https://bynk-lang.org/book/reference/testing/#platform-doubles):
  why `Fetch` needs a stub.
- [`concurrency`](../concurrency/): `par`, `race` and `within` in depth.
- [`actors-and-authorisation`](../actors-and-authorisation/): bearer-token
  actors and how tests supply them.
- [`queues`](../queues/): the other entry point with no caller.
- [`storage-and-queries`](../storage-and-queries/): when a `Cache` TTL or a
  `Log` retention does the reaping for you, with no job at all.
- [`testing`](../testing/): stubs, the test clock and test tiers.
