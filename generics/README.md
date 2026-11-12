# Generics

A support desk's ticket queue, built from small generic pieces. It shows type
parameters on functions and types, the `Eq`, `Ord` and `Key` bounds, how your
own types opt in to an order with `derives Ord` so that `sort`, `min` and a
generic `clamp` work on them, a static constructor for a generic type, and a
`Map` keyed by a record.

## The idea

A Bynk generic says what it needs in its signature. `T` on its own can be
anything, functions included, so a body may only move it around. To compare
with `==` you declare `T: Eq`; to use `<` or sort you declare `T: Ord`; to key
a `Map` you declare `K: Key`. If you forget, the compiler points at the
comparison and offers the fix, and a caller who passes the wrong type is
rejected at the call, not deep inside the generic.

Ordering is opt-in for the same reason. The compiler won't guess whether
`Urgent` comes before `Low`, so a type you declare is orderable only once you
write `derives Ord`, and then its order is its declaration order.

## Walkthrough

**`src/triage/generic.bynk`** holds generic code that knows nothing about
tickets. Each type parameter carries exactly the bound its body needs:

```bynk
fn occurrences[T: Eq](xs: List[T], x: T) -> Int {
	xs.filter((y) => y == x).length()
}

fn clamp[T: Ord](x: T, lo: T, hi: T) -> T {
	if x < lo { lo } else { if x > hi { hi } else { x } }
}

fn countBy[K: Key, V](xs: List[V], key: V -> K) -> Map[K, Int] {
```

`V` in `countBy` stays unbounded, because it is only handed to `key`. The same
file declares a generic type with the bound on the type, and statics as its
constructors. A static on `Sorted[T]` is generic over `T`, and the type's bound
holds inside it:

```bynk
type Sorted[T: Ord] = {
	items: List[T],
}

fn Sorted.fromList(xs: List[T]) -> Sorted[T] {
	Sorted { items: sort(xs) }
}

fn Sorted.empty() -> Sorted[T] {
	Sorted { items: [] }
}
```

`Sorted.fromList(xs)` infers `T` from its argument. `Sorted.empty()` has none,
so the caller writes `Sorted.empty[Int]()` or gives an expected type.

**`src/triage/tickets.bynk`** is the domain. `Urgent` is written first so it
is the smallest, which makes ascending order the order to work in:

```bynk
type Priority = enum { Urgent, Normal, Low } derives Ord

type Ticket = {
	priority: Priority,
	--- Minutes since the shift started.
	opened: Int,
	id: String,
	team: Team,
} derives Ord
```

A `Ticket` compares by priority, then by `opened`, then by `id`. With that in
place, the generic code applies directly: `min(ts)` picks the next ticket,
`Sorted.fromList(ts)` gives the worklist, and `clamp(p, Normal, Low)` stops an
automatic rule from setting `Urgent`. `Team` is a record of `String`s, so it is
a `Key` with nothing to declare, and `countBy(ts, (t) => t.team)` returns a
`Map[Team, Int]`.

A generic type may refer to itself. `Chain[T]` in `generic.bynk` is an
escalation chain, each step holding a `T` and an optional rest:

```bynk
type Chain[T] = {
	head: T,
	next: Option[Chain[T]],
}
```

It works anywhere inside the unit. It's refused only where a value crosses a
boundary, a handler signature, a `store` field or an event, because a
recursive generic has no codec yet (`bynk.generics.recursive_generic_at_boundary`).
Walking it is a self call in tail position, which Bynk runs as a loop, so a long
chain doesn't grow the stack.

**`tests/triage/`** checks the edges: an empty queue has no next ticket, a later
field only breaks ties, `clamp` holds across generated ranges (a `property`),
a map lookup by a `Team` built anew finds the same key, and a `Chain` reports
its length and last step.

## Run it

```sh
bynk test .
```

## Read next

- [Generics and bounds](https://bynk-lang.org/book/reference/generics/)
- [Declare `Eq` on a generic that compares](https://bynk-lang.org/book/guides/type-system/declare-eq-bounds/)
- [Understand ordering your own types](https://bynk-lang.org/book/guides/type-system/ordering-your-own-types/)
- [Constructors for generic types](https://bynk-lang.org/book/guides/type-system/constructors-for-generic-types/)
- [Key a map by a record](https://bynk-lang.org/book/guides/type-system/key-a-map-by-a-record/)
- [Generic code that crosses the boundary](https://bynk-lang.org/book/guides/type-system/generic-code-that-crosses-the-boundary/), for the `Codable` bound
- Sibling projects: [`pattern-matching`](../pattern-matching/) and
  [`storage-and-queries`](../storage-and-queries/), where the same `derives Ord`
  and record keys work in a store `Query`'s `sortBy` and `groupBy`.
