# Function contracts

Paging through a catalogue, with each function's terms written on the function:
what it needs from its caller (`requires`) and what it promises back
(`ensures`).

## The idea

A doc comment can say "`perPage` must be positive" and nothing holds anyone to
it. A contract says it in code, between a pure function's return type and its
body:

```bynk
fn pageCount(items: Int, perPage: Int) -> Int
	requires some_or_none: items >= 0 && items <= 1_000_000
	requires per_page: perPage >= 1 && perPage <= 100
	ensures holds_every_item: result * perPage >= items
	ensures no_empty_page: (result - 1) * perPage < items || result == 0
{
	(items + perPage - 1) / perPage
}
```

Each clause has a name and a predicate, the same pure `Bool` an `invariant` or
an `expect` takes. In an `ensures`, `result` is the return value.

A contract is checked in two places, without a test that asks for it:

- **At every call, in a test build.** A guard checks each `requires` on the way
  in and each `ensures` on the way out. A broken clause fails the call and names
  the clause and the values that broke it, so a caller's mistake is reported
  where it was made, not three functions later.
- **By the test runner.** For each contracted function a suite reaches, the
  runner generates arguments, keeps the ones that meet every `requires`, and
  checks every `ensures` on the result, as a `property` does. A failure comes
  back as a shrunk counterexample with a seed to reproduce it. A contract is a
  property that is always on.

Neither costs production anything. Whether a build keeps the guard is a
*profile* setting: `bynk test` builds `dev`, which keeps it, and `bynk deploy`
builds `release`, which never does.

## Walkthrough

[`src/catalogue/paging.bynk`](src/catalogue/paging.bynk) is a commons with two
functions. `pageCount` promises that its pages hold every item and that none is
empty. `offset`, the number of items before a page, requires pages numbered from
1 and promises a whole number of pages:

```bynk
fn offset(page: Int, perPage: Int) -> Int
	requires numbered_from_one: page >= 1 && page <= 10_000
	requires per_page: perPage >= 1 && perPage <= 100
	ensures from_the_start: result >= 0
	ensures whole_pages: result.rem(perPage) == 0
{
	(page - 1) * perPage
}
```

The upper bounds in the `requires` are part of the terms too: they say which
inputs the function is for, and they keep the runner's generated arguments in a
range where the arithmetic means something.

[`tests/catalogue/paging.bynk`](tests/catalogue/paging.bynk) pins down exact
answers, such as `pageCount(41, 20) == 3`, which no contract states. It doesn't
restate a contract: a case or `property` that only repeats an `ensures` is
flagged as redundant (`bynk.contract.restated_by_test`). Use `ensures` for a
claim about one result, and a `property` for one that relates several calls.

[`bynk.toml`](bynk.toml) writes out the `dev` profile's default:

```toml
[profile.dev]
contracts = true
```

Setting it to `false` turns the guard off for a test run. `bynk deploy` refuses
`[profile.release] contracts = true`, because a deployment never carries contract
checks.

## Run it

```sh
bynk test .
```

To see a contract fail, change `pageCount`'s body to `items / perPage` and run
the tests again: the runner finds an input where the pages no longer hold every
item.

## Read next

- [Testing reference: contracts](https://bynk-lang.org/book/reference/testing/#contracts)
- [`bynk.contract.*` errors](https://bynk-lang.org/book/troubleshooting/contract-errors/)
- [`[profile.<name>]` in the manifest](https://bynk-lang.org/docs/manifest/)
- Showcase: [`agent-state-machine`](../agent-state-machine/) for `invariant`s,
  the same predicates on an agent's state, and [`testing`](../testing/) for
  cases and properties.
