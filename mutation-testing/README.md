# Mutation testing

A delivery-charge rule and a suite that pins it down, checked with
`bynk test --mutate`: would the tests notice if the code were wrong?

## The idea

Passing tests show the code does what they ask. They don't show the tests would
fail if the code stopped doing it. Coverage can't tell you either: a line can
run in every case and still have nothing check its answer.

`bynk test --mutate` asks that question directly. It changes the code in `src/`
one small way at a time, runs the suites that reach it, and reports each change,
or *mutant*, that no case failed on:

- a comparison swapped for its neighbour (`>=` ↔ `>`, `==` ↔ `!=`);
- `&&` ↔ `||`;
- an `if` condition, or a `match` guard, replaced by `true` and by `false`;
- `+` ↔ `-`;
- in a `D1` call's SQL, `<` ↔ `<=`, `max(` ↔ `min(`, and one `AND` dropped
  from a `WHERE`.

A mutant that some case fails on is *killed*. One that every case passes is a
*survivor*: a change to the behaviour that the suite can't see. Each survivor
is reported with its file, line and exact change, so you can add the case that
would catch it.

Bynk can do this because tests are part of the language. It knows which suites
reach which unit, so each mutant runs only the suites that could notice it. A
mutant exists only in memory and runs in a scratch directory, so your files and
`out/` are never touched.

## Walkthrough

[`src/shop/delivery.bynk`](src/shop/delivery.bynk) is the rule. Members ship
free, and so does a basket worth £50 or more:

```bynk
fn charge(basket: Int, member: Bool) -> Int {
	if member || basket >= FreeFrom { 0 } else { Standard }
}

fn total(basket: Int, member: Bool) -> Int {
	basket + charge(basket, member)
}
```

That's five mutants: `||` → `&&`, `>=` → `>`, the `if` condition as `true` and
as `false`, and `+` → `-`.

[`tests/shop/delivery.bynk`](tests/shop/delivery.bynk) has one case per way the
rule could be wrong, and a comment on each says which mutant it kills. The one
that's easy to leave out is the boundary:

```bynk
case "a basket of exactly £50 ships free" {
	expect charge(5000, false) == 0
}
```

Without it, a suite that tries a £10 basket and a £60 one passes against both
`>=` and `>`, and `--mutate` reports `>=` → `>` as a survivor in `charge`. Add
the case and the mutant is killed.

CI holds this project to a score of 100%. The project opts in with
[`.mutation-gate`](.mutation-gate), which holds the minimum score, and CI runs:

```sh
bynk test --mutate --mutate-fail-under 100
```

## Run it

```sh
bynk test .
bynk test --mutate
```

The unmutated suites must pass first; otherwise every mutant would look killed
by the failure that was already there. `--mutate` exits `0` even when mutants
survive, so a report can run in CI without failing it, and
`--mutate-fail-under PERCENT` turns it into a gate. On a large project, keep the
run proportional to the change: `--changed origin/main` mutates only the files a
branch touched, and `--mutate-jobs 4` runs four mutants at once.

Not every survivor is a gap. A change that makes no observable difference (an
*equivalent* mutant) can't be killed by any test, so leave that code out with
`[test.mutate] exclude` in `bynk.toml`, by path glob or by declaration name:

```toml
[test.mutate]
exclude = ["src/shop/legacy/**", "shop.delivery.roundUp"]
```

Often, though, an equivalent mutant points to code that can be put more plainly.

## Read next

- [Run your tests: `--mutate`](https://bynk-lang.org/book/guides/testing/run-tests/)
- [`bynk test` mutation testing reference](https://bynk-lang.org/docs/bynk-cli/#mutation-testing)
- [`[test.mutate]` in the manifest](https://bynk-lang.org/docs/manifest/#testmutate)
- Showcase: [`testing`](../testing/) for suites, stubs and doubles, and
  [`sql-databases`](../sql-databases/) for D1 statements, whose SQL `--mutate`
  also changes.
