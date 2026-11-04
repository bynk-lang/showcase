# Results and optionals

A café till prices the order lines a barista types in. Some lookups simply find
nothing (a customer with no loyalty card), and some input is wrong (a product
the café doesn't sell, or "lots" as a quantity). This project shows how Bynk
models the first with `Option` and the second with `Result` and a domain error
type, how failure flows through a chain of steps, and how to convert between
the two.

## The idea

Bynk has no exceptions and no `null`. A value that may be missing is an
`Option[T]` (`Some` or `None`); an operation that may fail returns a
`Result[T, E]` (`Ok` or `Err`). Both are ordinary values, so the type of a
function tells you exactly what can go wrong, and the compiler makes you deal
with it before you can use what's inside.

Which one to use is a question about meaning. Absence is often fine: no card
means no discount. A failure the caller must explain gets an error type of its
own, here `OrderError`, whose variants carry the details the till shows. `?`
passes an `Err` straight back to the caller, `okOr` turns an absence into an
error where absence is a mistake, and `ok()` goes the other way when the
reason doesn't matter.

## Walkthrough

**`src/till/menu.bynk`**: lookups return `Option`. Finding the discount chains
two steps that may each come up empty, without a `match`:

```bynk
fn discountFor(card: Option[String]) -> Int {
	card.andThen(findMember).map((m) => m.percent).getOrElse(0)
}
```

**`src/till/order.bynk`**: the domain error type, then the steps that use it.

```bynk
type OrderError =
	| UnknownProduct(sku: String)
	| NotANumber(text: String)
	| OutOfRange(quantity: Int)
```

`parseQuantity` converts `Int.parse`'s `Option` with `okOr`, and the refined
type's `ValidationError` with `mapErr`, so callers see only `OrderError`.
`priceLine` then reads top to bottom, each `?` returning the first failure:

```bynk
fn priceLine(sku: String, quantity: String) -> Result[Int, OrderError] {
	let product = findProduct(sku).okOr(UnknownProduct(sku))?
	let n = parseQuantity(quantity)?
	Ok(product.pence * n)
}
```

The rest of the file builds on it: `subtotal` collects every line's `Result`
with `sequenceTry`, `total` applies the optional discount with `map`,
`preview` drops the error with `ok()` for a display that shows a price or
nothing, and `receiptLine` handles the error in place with `let … else match`:

```bynk
let Ok(pence) = priceLine(sku, quantity) else match {
	Err(error) => "refused: \(explain(error))",
}
```

**`tests/till/`**: each test exercises a branch: the good line, each
`OrderError` variant, the quantity bounds 1 and 20, a bad line spoiling a
whole order, and a loyalty discount that does not hide an error.

## Run it

```sh
bynkc test .
```

## Read next

- [Work with `Result` and optional values](https://bynk-lang.org/book/guides/type-system/result-and-optionals/)
- [Fault on the impossible or the unfinished](https://bynk-lang.org/book/guides/type-system/fault-on-the-impossible/),
  for the cases that are not errors a caller could handle
- [Type system reference](https://bynk-lang.org/book/reference/types/) and
  [Operators](https://bynk-lang.org/book/reference/operators/)
- Sibling projects: [refined-types](../refined-types/) for `Quantity.of`
  and `ValidationError`, and [pattern-matching](../pattern-matching/) for
  `match` on an error type
