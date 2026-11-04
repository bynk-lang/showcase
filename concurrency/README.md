# Concurrency

A product page that needs three slow lookups: stock, price and a delivery
estimate. It runs them at the same time with a `par` block, asks two price
mirrors and takes the first answer with `race`, and gives up on a slow courier
with `within`. The tests drive every outcome on virtual time with latency stubs,
so they never sleep.

## The idea

Each `<-` waits for its effect, so three independent calls cost the sum of their
latencies. Bynk gives you three tools, all built on effects:

- **`par { … }`** issues several effects together and waits for **all** of them.
  Unlike `Promise.all`, if one faults the block still waits for the others to
  settle, then raises the **first fault in source order**. Nothing it started
  outlives the handler, and the fault you see doesn't depend on timing.
- **`a.race(b)`** is the first of two effects to **succeed**. A side that faults
  fast doesn't win; the race waits for the other.
- **`e.within(d)`** gives `Err(TimedOut)` if the deadline passes first.

Neither `race` nor `within` cancels anything. The loser, or the late effect, is
handed to the platform's `waitUntil` and runs to completion, because cancelling
a Worker's promise could leave a write half done. So race only work that is
safe to do twice, and read `Err(TimedOut)` as "I didn't wait to find out", not
"nothing happened".

## Walkthrough

1. **`src/shop/product.bynk`** declares three capabilities and two helper
   functions. `fastestPrice` races the mirrors:

   ```bynk
   fn fastestPrice(sku: Int) -> Effect[Int] given Prices {
   	Prices.get("east", sku).race(Prices.get("west", sku))
   }
   ```

   `deliveryNote` bounds the courier by a named budget. `TimedOut` comes from
   `consumes bynk { TimedOut }`:

   ```bynk
   	let r <- Couriers.estimate(sku).within(EstimateBudget)
   	match r {
   		Ok(days) => Effect.pure("delivery in \(days) days"),
   		Err(TimedOut { .. }) => Effect.pure("delivery date to follow"),
   	}
   ```

   The handler joins all three. The names a block binds are in scope after its
   closing brace, and no binding may use a sibling's result:

   ```bynk
   		par {
   			let stock <- Stock.level(sku)
   			let price <- fastestPrice(sku)
   			let delivery <- deliveryNote(sku)
   		}
   ```

2. **`tests/shop/product.bynk`** stubs each capability with a latency. The
   harness moves its clock to the next timer whenever every call in flight is a
   waiting stub:

   ```bynk
   	stub Prices.get("east", _) returns 13 after 2.seconds
   	stub Prices.get("west", _) returns 12 after 1.seconds
   ```

   The cases cover the faster mirror winning, a fast fault losing the race, a
   courier that's slow, one that `never` answers and one that lands exactly on
   the deadline (a tie goes to the effect), plus a join where one branch
   faults: `expect page.call(7) faults`.

## Run it

```sh
bynkc test .
```

## Read next

- [Run independent calls at the same time](https://bynk-lang.org/book/guides/effects-and-capabilities/run-independent-calls-at-the-same-time/)
- [Ask two sources and take the first answer](https://bynk-lang.org/book/guides/effects-and-capabilities/ask-two-sources-and-take-the-first-answer/)
- [Bound how long a call may take](https://bynk-lang.org/book/guides/effects-and-capabilities/bound-how-long-a-call-may-take/)
- [What a join guarantees on failure](https://bynk-lang.org/book/guides/effects-and-capabilities/what-a-join-guarantees-on-failure/)
- [What a timeout stops](https://bynk-lang.org/book/guides/effects-and-capabilities/what-a-timeout-stops/)
- [Testing reference: latency and virtual time](https://bynk-lang.org/book/reference/testing/#stub-latency)
- Showcase: [`capabilities-and-providers`](../capabilities-and-providers/) for
  how a capability like `Prices` is declared and provided, and
  [`testing`](../testing/) for stubs and `expect … called`.
