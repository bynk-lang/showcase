# Idempotency

A client that never saw an answer retries, so the same order can arrive twice,
or two copies at once. With an `Idempotency-Key`, the first attempt places the
order and every repeat gets the first attempt's answer back.

## The idea

Anything delivered "at least once" (a retried request, a redelivered queue
message, a resent webhook) can arrive more than once. The `Idempotency`
capability has two tools for that:

- **`claim(key, expiresAfter)`** is first-delivery-wins. Exactly one caller
  gets `Claimed` for a key; every other gets `AlreadyClaimed` until the window
  ends. It's atomic, so two copies arriving together can't both win.
- **`dedup[T](key)` and `remember[T](key, value, expiresAfter)`** are a cache of
  outcomes. `remember` keeps a `Codable` value, and `dedup` reads it back. On
  its own that's check-then-act, so two simultaneous copies could both miss.

Together they give a repeat the same answer without doing the work twice:
claim first, and only the winner computes and remembers.

The compiler settles a claim when the handler ends. A failure (a fault, a
returned `Err`, a 5xx) releases it, so the client's retry is processed. A 4xx
or a success keeps it for the whole window. A claim is also a 30-second lease
until then, so a Worker cut off mid-request doesn't hold a key for a day.

That's at-most-once *completion*, not exactly-once side effects: work done
before a failure can happen again on the retry. Pass the key along to anything
you call, so it can deduplicate too.

## Walkthrough

[`src/shop/orders.bynk`](src/shop/orders.bynk) has one route:

```bynk
let claimed <- Idempotency.claim(key, KeyWindow)
match claimed {
	AlreadyClaimed => {
		let earlier <- Idempotency.dedup[Outcome](key)
		match earlier {
			Some(outcome) => answer(outcome),
			None => Conflict("this order is still being placed, try again shortly"),
		}
	},
	Claimed => …
}
```

The winner asks `Warehouse` to reserve stock, passing the key along, and
remembers how that ended, as an `Outcome`: `Placed(reservation)` or `SoldOut`.
Both are finished answers, and `answer` turns either into the same response
every time. A warehouse outage remembers nothing and answers `503`, so the
claim is released and the retry tries again.

Keys are scoped to the function that calls `claim`, `dedup` or `remember`, so
two handlers can't collide on the same key, and the calls stay in the handler
rather than in a helper that every caller would share.

On Cloudflare, claims and remembered values live in a D1 database that the
build declares for you: `bynk deploy` creates it, and you write no SQL.

[`tests/shop/orders.bynk`](tests/shop/orders.bynk) runs on the in-memory double,
which honours each window on the test clock. A retry gets `Created("r-1")`
again and `Warehouse.reserve` is `called once`; a `503` gives the key back; an
out-of-stock answer is kept even after stock returns; and `advance Clock by
25.hours` lets the key be used afresh.

## Run it

```sh
bynk test .
```

The tests stub `Warehouse`. Its provider, `HttpWarehouse`, calls a warehouse
API at `WAREHOUSE_URL` and passes the order's key along as its own
`Idempotency-Key`, so a reservation made just before a failure isn't made
twice on the retry.

## Read next

- [Deduplicate at-least-once deliveries](https://bynk-lang.org/book/guides/effects-and-capabilities/deduplicate-at-least-once-deliveries/)
- [The `Idempotency` capability](https://bynk-lang.org/book/reference/bynk-capabilities/#the-idempotency-capability)
- [Deploy to Cloudflare: the idempotency database](https://bynk-lang.org/book/guides/projects-build-and-deployment/deploy-to-cloudflare/#the-idempotency-database)
- Showcase: [`queues`](../queues/) and [`verify-webhooks`](../verify-webhooks/),
  two more places deliveries repeat.
