# Events

In-system publish and subscribe. A checkout announces each order as an
`OrderPlaced` event. Two other contexts, loyalty points and a sales tally, hear
it and react, and the checkout never names either of them.

## The idea

A context declares an `event`, a typed record of something that happened, and
emits it with the `Events` capability. Any other context that `consumes` the
publisher can subscribe with a `from Events(E)` service. The compiler wires the
delivery, so the publisher's code has no list of listeners to keep up to date.

What that buys you:

- **Decoupling.** `shop.orders` has no idea `shop.loyalty` or `shop.sales`
  exist. A new listener is a new service in its own context, and the checkout
  doesn't change.
- **Ownership.** Only the context that declares an event may emit it. A
  subscriber can see `OrderPlaced` but can't forge one.
- **Filtering in the header.** A subscription can carry a pattern, so the
  loyalty scheme only runs for domestic orders. Every subscriber is still
  delivered every emission; its generated handler drops the ones that don't
  match before your code runs.
- **Honest delivery.** Delivery is at least once, so a subscriber with effects
  must cope with seeing an order twice. Both subscribers here dedup on the
  order's own id, inside the agent handler that does the work, so the check and
  the update commit together or not at all.

## Walkthrough

1. [`src/shop/orders.bynk`](src/shop/orders.bynk): the publisher. It declares
   the event and emits it only after an order passes its check, so a refused
   order is never announced:

   ```bynk
   event OrderPlaced = {
   	orderId: String,
   	customer: String,
   	region: Region,
   	totalPence: Int,
   }
   ```

2. [`src/shop/loyalty.bynk`](src/shop/loyalty.bynk): a filtered subscriber.
   It ignores international orders through its header pattern. The `Points`
   agent refuses an order it has already awarded:

   ```bynk
   on call award(orderId: String, points: Int) -> Effect[()] given Clock {
   	let seen <- awarded.get(orderId)
   	match seen {
   		Some(_) => (),
   ```

   Why `orderId` and not the envelope's `eventId`? A redelivery repeats the
   `eventId`, but a customer resubmitting a checkout that timed out produces a
   second emission with a fresh one. Only the order id catches both. And why in
   the agent, not with the `Idempotency` capability? Its `dedup` and `remember`
   are separate calls from the award, so a fault between them could lose the
   points or award them twice. The agent's store commits the mark and the
   balance as one.

3. [`src/shop/sales.bynk`](src/shop/sales.bynk): an unfiltered subscriber
   that tallies every order, whatever its region, and dedups the same way.
4. [`tests/shop/orders.bynk`](tests/shop/orders.bynk): the publisher alone.
   `Events` is a double under test, so a case checks the emission with
   `expect Events.emit called once`, and `called 0 times` for a refused order.
5. [`tests/shop/loyalty.bynk`](tests/shop/loyalty.bynk): the subscriber
   alone. `AwardPoints.event(e)` delivers one event through the same
   generated handler the fan-out uses, so the pattern filter applies. Delivering
   the same order twice earns its points once, whatever the envelope says:

   ```bynk
   let _ <- AwardPoints.event(order("o-1", Region.Domestic))
   let _ <- AwardPoints.event(order("o-1", Region.Domestic))
   let points <- Points("ada").current()
   expect points == 25
   ```

6. [`tests/shop/sales.bynk`](tests/shop/sales.bynk): the second listener
   counts the international order that loyalty ignored, and counts a
   redelivered order once.

Each side is tested without the other. That's the decoupling again: the
publisher's suite runs no subscriber, and the subscribers' suites need no
checkout.

## Run it

```sh
bynkc test .
```

## Read next

- [Understand events](https://bynk-lang.org/book/guides/events/understand-events/)
- [Delivering an event](https://bynk-lang.org/book/reference/testing/#event-address)
  in the testing reference
- [First-party `bynk` capabilities](https://bynk-lang.org/book/reference/bynk-capabilities/),
  for `Events`, and `Idempotency` for dedup without an agent
- Showcase: [`queues`](../queues/) for point-to-point messages with retries,
  [`agent-state-machine`](../agent-state-machine/) for the agents that hold the
  points, and [`testing`](../testing/) for doubles and suites.
