# Money

Money is `Decimal`, not `Float`. This project shows exact arithmetic
(`0.1d + 0.2d == 0.3d`), refined `Price` and `Rate` types, tax rounded in one
named place, and a total split between people without losing a cent.

## The idea

A `Float` cannot hold `0.1`, so sums drift. A `Decimal` is exact: `+`, `-` and
`*` never round, and rounding happens only where you write it. `/` is not defined
on `Decimal`, because a quotient like one third has no exact answer. Division
(`div`) states the scale and the rounding mode, and whatever it discards is an
exact `Decimal` you can hand out.

## Walkthrough

**`src/shop/pricing.bynk`** starts with the types. A literal ends in `d`:

```bynk
type Price = Decimal where Positive

type Rate = Decimal where InRange(0.00d, 1.00d)
```

Tax multiplies exactly, then rounds once, to cents, half-even:

```bynk
fn withTax(net: Decimal, rate: Rate) -> Decimal {
	(net + net * rate).round(2, RoundingMode.HalfEven)
}
```

Splitting uses `div` with `RoundingMode.Down`, which never overstates a share.
The cents it dropped are recovered exactly and given to the first shares:

```bynk
fn baseShare(total: Decimal, ways: Int) -> Decimal {
	total.div(Decimal.fromInt(ways), 2, RoundingMode.Down)
}

fn shareAt(total: Decimal, ways: Int, i: Int) -> Decimal {
	if i < leftoverCents(total, ways) {
		baseShare(total, ways) + 0.01d
	} else {
		baseShare(total, ways)
	}
}
```

Ten split three ways is `3.34 + 3.33 + 3.33`, which is exactly `10.00`.

**`tests/shop/pricing.bynk`** checks the feature itself: exact addition,
refinement bounds, half-even tax, and that the shares sum back to the total.

```bynk
case "decimal addition is exact" {
	expect 0.1d + 0.2d == 0.3d
	expect 1.10d + 2.20d == 3.30d
}
```

## Run it

```sh
bynk test .
```

## Read next

- [Handle money correctly](https://bynk-lang.org/book/guides/type-system/handle-money-correctly/)
- [Reference: Decimal](https://bynk-lang.org/book/reference/types/#decimal)
- Sibling project: [refined-types](../refined-types/) for how `Price.of` and
  literal admission work.
