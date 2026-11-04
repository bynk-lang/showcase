# Storage and queries

A shop's stockroom, kept in one agent. It shows the storage kinds an agent has
beyond a single `Cell`: a `Map` for the catalogue, a `Cache` whose entries lapse
on their own, and an append-only `Log`. It also shows the `Query[T]` vocabulary
that reads them: `filter`, `sortBy`, `map`, `collect`, the aggregates `count` and
`sum`, `groupBy`, and an `@indexed` field. A tiny HTTP service sits in front.

## The idea

An agent's state is a set of typed `store` fields, and each field's *kind* says
how the data lives:

- a `Map[K, V]` is keyed records, read with lazy queries;
- a `Cache[K, V]` is a `Map` whose entries expire after `@ttl`;
- a `Log[T]` is a time-stamped, append-only history, trimmed by `@retain`.

You don't write a sweep job, an expiry check or an index table. The annotations
say what you want, and the runtime maintains it inside the handler's atomic
commit.

Reads over a `store Map` or `Log` are a `Query[T]`. Builders like `filter` and
`sortBy` stay lazy; a *terminal* (`collect`, `count`, `sum`) runs the query and
returns an `Effect`, so you await it like any other storage operation. The
vocabulary is the same one a `List` carries, so there's nothing new to learn,
only where it runs. And because an equality filter on an `@indexed` field is
routed through the index, you get a lookup instead of a scan without changing
the query text.

## Walkthrough

[`src/stockroom/goods.bynk`](src/stockroom/goods.bynk) holds the domain types:
`Product`, the `Delivery` log entry, and `AisleStock`, the named row `groupBy`
projects into (Bynk has no anonymous tuples).

[`src/stockroom/shop.bynk`](src/stockroom/shop.bynk) is the `Stockroom` agent.
Its three fields, one of each kind:

```bynk
store products: Map[Sku, Product] @indexed(by: aisle)
store holds: Cache[HoldCode, Sku] @ttl(15.minutes)
store deliveries: Log[Delivery] @retain(30.days)
```

A query chain reads the `Map`. The aisle filter is an equality on the indexed
field, so it becomes an index lookup:

```bynk
on call aisle(name: Aisle) -> Effect[List[Product]] {
	products.filter((p) => p.aisle == name).sortBy((p) => p.priceCents).collect()
}
```

An aggregate is a terminal too, and an empty catalogue sums to `0`:

```bynk
on call stockValue() -> Effect[Int] {
	products.sum((p) => p.priceCents * p.onHand)
}
```

`groupBy` takes a key and an `into` combiner that builds one named row per
group. Inside the combiner, `rows` is an ordinary `List`:

```bynk
on call byAisle() -> Effect[List[AisleStock]] {
	products.groupBy((p) => p.aisle, (a, rows) => AisleStock {
		aisle: a,
		products: rows.count(),
		units: rows.sum((r) => r.onHand),
	}).sortBy((s) => s.aisle).collect()
}
```

`restock` reads with `get`, writes with `put` and appends a `Delivery` to the
`Log`. `append` stamps the time, so the handler declares `given Clock`. The
`Cache` handlers `hold` and `held` need the clock too, because a cache op
stamps or checks an expiry. The window read `deliveriesSince` takes its cutoff
as an argument, so it doesn't.

[`tests/stockroom/shop.bynk`](tests/stockroom/shop.bynk) drives the agent
directly. A handler's `List` result compares with `==`, so the tests assert on
the sorted lists themselves. A stubbed `Clock` reads a hold a millisecond before
its 15 minutes are up and again at exactly 15 minutes, when it has lapsed.
`expect Clock.now called once` shows that the window reads never touch the
clock. [`tests/stockroom/boundary.bynk`](tests/stockroom/boundary.bynk) sends raw
JSON to show that a negative price or count never gets past the boundary.

## Run it

```sh
bynkc test .
bynk dev
```

With `bynk dev` running, `POST /products` shelves a product, `GET /stock/value`
values the stockroom, and `GET /stock/low` lists shelves with fewer than five
units.

## Read next

- [Agents](https://bynk-lang.org/book/reference/agents/): the storage kinds,
  their operations and the annotations.
- [Query](https://bynk-lang.org/book/reference/types/#query): every builder and
  terminal, plus joins.
- [Build a stateful agent](https://bynk-lang.org/book/guides/agents-and-state/stateful-agent/)
- [`agent-state-machine`](../agent-state-machine/): an agent built on a `Cell`
  and invariants.
- [`generics`](../generics/): the generic types `Map[K, V]` and `Query[T]` are
  built from.
