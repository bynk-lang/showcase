# Queues

A warehouse takes orders over HTTP and packs them later. The HTTP route puts a
packing job on a queue and answers straight away; a queue consumer takes each
job off the queue and decides what happens to it. The project shows both ends
of a queue, the three verdicts a consumer reaches (pack it, try again later,
drop it), and the difference between a send you wait for and one you don't.

## The idea

A queue consumer is a `service … from queue("name")` with one `on message`
handler. The handler doesn't call an ack API. It returns a `QueueResult`
verdict: `Ack` removes the message, and `Retry(reason)` asks the platform to
deliver it again. The verdict is separate from success or failure, so a message
that can never succeed is `Ack`ed to drop it rather than retried until the
dead-letter queue takes it.

On the producer side, `Queue @name("packing")` from `bynk.cloudflare` is a
capability like any other, so the route names it in `given`. The route waits
for the send with `let _ <-`, because it must not promise work that isn't on the
queue yet. Its log line uses `~>`, Bynk's fire-and-forget send, because nothing
depends on it finishing.

## Walkthrough

1. [`src/warehouse/packing.bynk`](src/warehouse/packing.bynk): one context.
   `Order` is what a customer posts, with a refined `Sku` and `Quantity`.
   `PackJob` is the message on the queue, and its fields are plain on purpose:
   the consumer checks them itself, so it can drop a bad job instead of
   retrying it. The route enqueues:

   ```bynk
   let _ <- Packing.sendValue(PackJob { sku: body.sku, quantity: body.quantity })
   ~> Logger.info("queued \(body.quantity) x \(body.sku)")
   Accepted("queued")
   ```

   The consumer admits the job, then lets the `Shelf` agent decide between
   `Ack` and `Retry`:

   ```bynk
   Ok(quantity) => {
   	let taken <- Shelf(sku).take(quantity)
   	if taken {
   		~> Logger.info("packed \(quantity) x \(sku)")
   		Ack
   	} else {
   		Retry("not enough \(sku) in stock")
   	}
   },
   ```

2. [`tests/warehouse/system.bynk`](tests/warehouse/system.bynk): the consumer
   at the `system` tier. `packer.message(…)` sends each job through a JSON round
   trip and the Worker's real `queue` entry point, and yields the verdict. State
   carries through a case, so a retried job succeeds once the shelf is
   restocked:

   ```bynk
   let first <- packer.message(PackJob { sku: "MUG-001", quantity: 3 })
   expect first is Retry("not enough MUG-001 in stock")
   let _ <- api.POST("/stock/:sku", "MUG-001", 3) by Visitor
   let second <- packer.message(PackJob { sku: "MUG-001", quantity: 3 })
   expect second is Ack
   ```

   Malformed jobs (an unknown SKU, an impossible quantity) are acknowledged and
   leave the stock alone. The last case shows the HTTP boundary refusing a bad
   order with `Wire(…)` before anything is queued.

3. [`tests/warehouse/packing.bynk`](tests/warehouse/packing.bynk): in process,
   where the queue producer and `Logger` are recording doubles. A case can see
   that the route sent one message and logged once, and that a malformed job
   was dropped with a warning. In tests nothing sent to the queue reaches the
   consumer, which is why the consumer tests deliver messages themselves.

## Run it

```sh
bynkc test .
bynk dev
```

`Queue` is experimental, so `bynk.toml` lists `"bynk.cloudflare.Queue"` under
`[unstable] allow`.

## Read next

- [Process a queued message](https://bynk-lang.org/book/guides/entry-points/queue/)
- [Synchronous and asynchronous sends](https://bynk-lang.org/book/guides/effects-and-capabilities/synchronous-and-asynchronous-sends/)
- [Queue reference](https://bynk-lang.org/book/reference/queue/)
- [Sending to a queue: `Queue`](https://bynk-lang.org/book/reference/bynk-capabilities/)
- [Testing: cron and queue at `system`](https://bynk-lang.org/book/reference/testing/)
- Sibling projects: [`scheduled-jobs`](../scheduled-jobs/) (the other
  non-HTTP entry point), [`events`](../events/),
  [`capabilities-and-providers`](../capabilities-and-providers/) and
  [`testing`](../testing/).
