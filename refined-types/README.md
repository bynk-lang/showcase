# Refined types

A refined type is a base type narrowed by a predicate: `Int where InRange(1, 99)`
is an `Int`, but only some of them. This project shows the three ways a value can
meet one. A literal is checked at compile time. A value computed at runtime goes
through `.of` and a `Result`. Untrusted input is checked once, at the HTTP
boundary, before any handler runs. It uses a tiny shop: order lines with a SKU
and a quantity.

## The idea

The predicate is part of the type. A `Quantity` of 240 is not a bug you forgot to
catch: it is a value that cannot exist. So validation happens exactly once, where
a value enters the type, and every function past that point can rely on it.

A refined type has only two doors, and neither is unchecked:

- **A literal** written where the refined type is expected (a return position, an
  annotated `let`, an `Ok`/`Some`/`Err` payload, a call argument) is checked
  against the predicate by the compiler and admitted as it is. An invalid literal
  does not compile.
- **Anything else** goes through `T.of(value)`, which always returns
  `Result[T, ValidationError]`, so the failure case can't be ignored.

A typed HTTP parameter (a path segment or a `body`) uses the second door for you:
the router runs the predicates and answers `400 RefinementViolation` before the
handler is called.

## Walkthrough

**`src/orders/stock.bynk`** declares the types. The predicates sit in the type:

```bynk
type Sku = String where Matches("[A-Z]{3}-[0-9]{4}")

--- How many of one item a single order line may ask for.
type Quantity = Int where InRange(1, 99)
```

Returning `1` where a `Quantity` is expected is literal admission. There is no
`.of` and no `Result`, because the compiler has already checked it:

```bynk
fn firstQuantity() -> Quantity {
	1
}
```

Change that `1` to `0` and the project stops building:

```text
[bynk.refine.literal_violates] Error: literal 0 does not satisfy `InRange` required by type `Quantity`
```

`linePrice` takes a `Line` and does no checking at all. Arithmetic, though, yields
the base type, so `line.qty + 1` is a plain `Int` that might be 100. It has to go
back through `.of`:

```bynk
fn addOne(line: Line) -> Result[Line, ValidationError] {
	let qty = Quantity.of(line.qty + 1)?
	Ok(Line { sku: line.sku, qty: qty })
}
```

**`src/orders/web.bynk`** is the boundary. Both handlers take refined values
directly, so neither of them validates anything:

```bynk
on POST("/quotes") (body: Line) -> Effect[HttpResult[Int]] by Visitor {
	Ok(linePrice(body))
}
```

**`tests/orders/stock.bynk`** covers the edges: 1 and 99 are accepted, 0 and 100
are refused, a lowercase or short SKU is refused, and `addOne` fails at 99.

**`tests/orders/web.bynk`** runs at the `system` tier, across the real
JSON boundary. A `Wire(...)` argument sends raw text, as a client would, so the
rejection can be tested:

```bynk
case "a quantity of zero is refused before the handler runs" {
	let r <- api.POST("/quotes", Wire("{\"sku\": \"TEA-0042\", \"qty\": 0}")) by Visitor
	expect r is Rejected(RefinementViolation(_))
}
```

## Run it

```sh
bynk test .
bynk dev        # then: curl -X POST localhost:8787/lines/TEA-0042
```

## Read next

- [Define a refined type and validate untrusted input](https://bynk-lang.org/book/guides/type-system/define-and-validate/)
- [The refined-literal admission model](https://bynk-lang.org/book/guides/type-system/refined-literal-admission/)
- [Use a literal where a refined type is expected](https://bynk-lang.org/book/guides/type-system/use-a-literal/)
- [Refined-type API](https://bynk-lang.org/book/reference/refined-types/)
- [The type-system philosophy](https://bynk-lang.org/book/guides/type-system/philosophy/)
- Sibling projects: [results-and-optionals](../results-and-optionals/) for handling
  the `Result` that `.of` returns, and [pattern-matching](../pattern-matching/).
