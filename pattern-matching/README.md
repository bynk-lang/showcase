# Pattern matching

A parcel depot, taken apart with patterns. One sum type says where a parcel
is, and a handful of functions read it with `match`: by variant, by a range
of weights, by the shape of a scan history, by the fields of a record. Then
`is` and `let` do the same jobs when you only need one branch.

## The idea

A `match` in Bynk must cover every case, and the compiler checks it. Leave out
a variant, a band of numbers or a length of list, and the program does not
compile; the error names the missing pattern, ready to paste in as a new arm.
There is no fall-through and no "default" you forgot to think about.

Patterns are one small language used in three places. The same
`Delivered(signedBy)` or `Parcel { status, .. }` works as a `match` arm, after
`is` (a `Bool` test that binds for one branch), and on the left of a `let`. So
you learn the shapes once and pick the form that fits the question.

## Walkthrough

`src/parcels/parcel.bynk` defines the data. `Status` is a sum type: each
variant carries only what makes sense for it.

```bynk
type Status =
	| Booked
	| InTransit(hub: String, daysLeft: Int)
	| Delivered(signedBy: String)
	| Returned(reason: ReturnReason)
```

`src/parcels/tracking.bynk` reads it. `describe` has an arm per variant; a
literal (`0`) or a nested variant (`Refused`) in a payload narrows an arm
further, and the compiler still checks that every case is covered:

```bynk
InTransit(hub, 0) => "out for delivery from \(hub)",
InTransit(hub, daysLeft) => "at \(hub), \(daysLeft) days away",
```

`postage` matches an `Int` against bands. Both ends of `lo..hi` are included,
and the five arms cover every `Int` with no `_`:

```bynk
match grams {
	..0 => None,
	1..100 => Some(85),
	101..2000 => Some(320),
	2001..20000 => Some(695),
	20001.. => None,
}
```

`route` matches a list by its length, binding elements as it goes. `nextAction`
looks inside a `Parcel` and its status at once, and mixes in a range:

```bynk
Parcel { status: Returned(BadAddress), id, .. } => "correct the address on \(id)",
Parcel { status: Returned(_), id, .. } => "restock \(id)",
Parcel { status: InTransit(_, 0), grams: 20001.., .. } => "send a two-person crew",
```

Every record pattern ends with `..`, so adding a field to `Parcel` breaks none
of them.

When one branch is enough, `is` tests and binds, and `let` destructures. A
`let` whose pattern can fail needs an `else`:

```bynk
if parcel.status is InTransit(hub, _) { Some(hub) } else { None }

let Parcel { status: Delivered(signedBy), .. } = parcel else { None }
```

`tests/parcels/tracking.bynk` checks each function, including the edges: both
ends of a postage band, the weights no band accepts, each list length, and the
parcels that fall through to `_`.

## Run it

```sh
bynkc test .
```

## Read next

- [Pattern-match with `match`](https://bynk-lang.org/book/guides/type-system/match/)
- [Match on a record's fields](https://bynk-lang.org/book/guides/type-system/match-on-a-records-fields/)
- [Match on a list's shape](https://bynk-lang.org/book/guides/type-system/match-on-a-lists-shape/)
- [Match on a range of numbers](https://bynk-lang.org/book/guides/type-system/match-on-a-range-of-numbers/)
- [Narrow and bind with `is`](https://bynk-lang.org/book/guides/type-system/narrow-with-is/)
- [Destructure a record with `let`](https://bynk-lang.org/book/guides/type-system/destructure-a-record-with-let/)
- [Define types](https://bynk-lang.org/book/guides/type-system/define-types/)
- Sibling projects: [results-and-optionals](../results-and-optionals/) for
  `Option`, `Result` and `let … else`, and [generics](../generics/).
