# Public surface

How a Bynk program is shaped across units. A library `commons`, `postage.rates`,
prices parcels and keeps a small, deliberate public surface: everything about
*how* a price is built is `private`. A `context`, `postage.desk`, brings it in
with `uses` and serves quotes over HTTP. The library also takes optional
settings through an options record, so it can grow a new option without
breaking a caller.

## The idea

Every declaration is public by default. Marking a helper, type or constant
`private` keeps it inside its own unit: visible across the unit's files and to
the unit's own suite, never through `uses`. The public surface is then exactly
what you chose to export, and the rest can change freely.

The compiler holds the line in both directions:

- A unit that `uses` the commons can't reach a private name. Calling `bandFor`
  from the desk is refused with `bynk.visibility.private_item`, which says *why*
  rather than reporting an unknown function.
- A public signature can't leak a private type. Making `describe` return a
  `Band` is refused with `bynk.visibility.private_in_public`, since an importer
  could neither name nor build one.

Bynk has no optional parameters or overloading, so optional settings go in an
options record whose field defaults reproduce the plain operation. Adding an
option is one more defaulted field, and every existing literal still compiles.

## Walkthrough

**`src/postage/rates.bynk`** is the library. Its module doc says what the
surface is, and carries a `bynk test` example that `bynk test` runs. The
options record defaults every field:

```bynk
type QuoteOptions = {
	--- Which service carries the parcel.
	speed: Speed = Speed.Standard,
	--- Ask for a signature on delivery.
	signed: Bool = false,
}
```

The plain operation is the options form with every default:

```bynk
fn quote(weight: Grams) -> Int {
	quoteWith(weight, QuoteOptions {})
}
```

Below a `//` ruler, the details are private. `Band` never appears in a public
signature: `describe` hands out a `String` instead.

```bynk
private const ExpressSurcharge: Int = 300

private const SignatureFee: Int = 175
```

**`src/postage/desk.bynk`** is the context. It sees only the public surface.
Its request type reuses the library's options record, defaulted, so a body
without `options` gets a plain quote and a new option reaches the wire without
the desk changing:

```bynk
type QuoteRequest = {
	weight: Grams,
	options: QuoteOptions = QuoteOptions {},
}
```

**`tests/postage/rates.bynk`** targets the library, so it may call the private
`bandFor` and `surcharge` directly and test the band edges (1000 g is small,
1001 g is medium). A suite sees its own target's privates and nothing else's.

**`tests/postage/desk.bynk`** runs at the `system` tier with raw `Wire(...)`
bodies: a body with no options, one option, both options, and an overweight
parcel refused before the handler runs. An enum travels as `{"kind": "…"}`.

The two visibility errors above can't be written as passing tests, so here is
what the compiler prints for each edit:

```text
src/postage/desk.bynk:33:11: error[bynk.visibility.private_item]: `bandFor` is a private function of `postage.rates`
src/postage/rates.bynk:50:27: error[bynk.visibility.private_in_public]: public function `band` names `Band`, a private type of `postage.rates`
```

The first comes from `pence: bandFor(body.weight).pence` in the desk; the
second from adding `fn band(weight: Grams) -> Band` to the library.

## Run it

```sh
bynk test .
bynk dev        # then:
curl -X POST localhost:8787/quotes \
  -d '{"weight": 4200, "options": {"speed": {"kind": "Express"}}}'
```

## Read next

- [How a Bynk program is shaped](https://bynk-lang.org/book/guides/program-structure/how-a-program-is-shaped/)
- [Design a library's public surface with `private`](https://bynk-lang.org/book/guides/program-structure/design-a-public-surface/)
- [Add an option without breaking callers](https://bynk-lang.org/book/guides/program-structure/add-an-option/)
- [Document your code](https://bynk-lang.org/book/guides/program-structure/document-your-code/)
- [Consume another context's services with `consumes`](https://bynk-lang.org/book/guides/program-structure/consume-services/),
  the context-to-context counterpart of `uses`
- Sibling projects: [refined-types](../refined-types/) for the `Grams` range
  checked at the boundary, and [testing](../testing/) for suites and tiers.
