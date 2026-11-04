# Scheduled jobs

An uptime monitor driven by two cron schedules. Every five minutes it probes
each watched URL with `Fetch` and records what it found. At 03:00 each day it
stops watching any target that hasn't answered healthily for a day. A small HTTP
service adds targets and reads them back, and the tests fire both schedules at
chosen virtual times.

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
upstream that is down is data to record, not a failed run.

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
handler turns `at` into an `Instant` before doing anything else. The probe maps
a `FetchError` to a recorded `Unreachable`:

```bynk
let probe = match res {
	Ok(r) => Answered(r.status),
	Err(_) => Unreachable,
}
```

The sweep measures its cut-off from the scheduled time:

```bynk
on schedule("0 3 * * *") (at: Int) -> Effect[Result[(), String]] given Logger {
	let gone <- Watchlist(Everything).retire(Instant.fromEpochMillis(at))
```

[`tests/uptime/monitor.bynk`](tests/uptime/monitor.bynk) is the unit suite. It
fires each schedule with `jobs.schedule("<expr>", at)`, stubs what the upstream
answers, and reads the effect back over HTTP. It covers a healthy answer, an
upstream that is down, an empty watchlist (no request is sent), and a 5xx that
doesn't count as a sign of life:

```bynk
stub Fetch.send(_) returns Err(Network)
let _ <- api.POST("/targets", NewTarget { name: "shop", url: "https://shop.test" }) by Visitor
let r <- jobs.schedule("*/5 * * * *", 300000)
expect r is Ok(_)
```

[`tests/uptime/sweep.bynk`](tests/uptime/sweep.bynk) runs `as system`, so the
schedule fires through the Worker's real `scheduled` entry point. A `stub` isn't
allowed there, so it drives only the sweep. `advance Clock` stamps two targets
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
starts watching a URL, and `GET /targets/<name>` reads it back. Its last probe
reads `Unchecked` until the five-minute schedule has run.

## Read next

- [Run a task on a schedule](https://bynk-lang.org/book/guides/entry-points/cron/)
- [Cron reference](https://bynk-lang.org/book/reference/cron/): the handler
  form and its rules.
- [Cron and queue at `system`](https://bynk-lang.org/book/reference/testing/#cron-queue-system)
- [Platform capabilities under test](https://bynk-lang.org/book/reference/testing/#platform-doubles):
  why `Fetch` needs a stub.
- [`queues`](../queues/): the other entry point with no caller.
- [`storage-and-queries`](../storage-and-queries/): when a `Cache` TTL or a
  `Log` retention does the reaping for you, with no job at all.
- [`testing`](../testing/): stubs, the test clock and test tiers.
