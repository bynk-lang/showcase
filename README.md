# Bynk showcase

Small, focused Bynk projects. Each one shows a single language feature, or a
small group of closely related ones, written the way Bynk is meant to be
written. If you're new to Bynk, read these to see what idiomatic code looks
like.

Every project stands on its own. Each has its own `bynk.toml`, sources, tests
and a README covering what the feature is, why Bynk does it that way, and what
to read next in [the book](https://bynk-lang.org/book/).

## Projects

| Project | Shows | Book |
|---|---|---|
| [`refined-types`](refined-types/) | refined types, literal admission, validating at the boundary | [Define and validate](https://bynk-lang.org/book/guides/type-system/define-and-validate/) |
| [`results-and-optionals`](results-and-optionals/) | `Result`, optionals, and propagating failure | [Result and optionals](https://bynk-lang.org/book/guides/type-system/result-and-optionals/) |
| [`pattern-matching`](pattern-matching/) | `match` on records, lists and ranges; narrowing with `is` | [Match](https://bynk-lang.org/book/guides/type-system/match/) |
| [`generics`](generics/) | generic types and functions, `Eq`/`Ord` bounds, ordering your own types | [Generics](https://bynk-lang.org/book/reference/generics/) |
| [`capabilities-and-providers`](capabilities-and-providers/) | `given`, declaring a capability, providing and wrapping one | [The capability model](https://bynk-lang.org/book/guides/effects-and-capabilities/understand-the-capability-model/) |
| [`agent-state-machine`](agent-state-machine/) | agents, a `Cell`, and invariants | [State machine](https://bynk-lang.org/book/guides/agents-and-state/state-machine/) |
| [`storage-and-queries`](storage-and-queries/) | agent storage (`Map`, `Cache`, `Log`) and `Query[T]` | [Agents](https://bynk-lang.org/book/reference/agents/) |
| [`sql-databases`](sql-databases/) | a D1 database: migrations, `"""sql` statements, typed reads with `select[T]` and `firstAs[T]`, `Sql` and `Decode` errors | [Query rows into a record](https://bynk-lang.org/book/guides/effects-and-capabilities/query-rows-into-a-record/) |
| [`testing`](testing/) | tests in the language: stubs, platform doubles, fixtures | [Write tests](https://bynk-lang.org/book/guides/testing/write-tests/) |
| [`actors-and-authorisation`](actors-and-authorisation/) | public and authenticated routes, claim checks, an agent keyed by the caller | [Authorisation](https://bynk-lang.org/book/guides/actors/authorisation/) |
| [`verify-webhooks`](verify-webhooks/) | signed webhooks verified for you; signing your own data | [Verify webhooks](https://bynk-lang.org/book/guides/actors/verify-webhooks/) |
| [`scheduled-jobs`](scheduled-jobs/) | cron handlers, driven from tests at a chosen time | [Cron](https://bynk-lang.org/book/guides/entry-points/cron/) |
| [`queues`](queues/) | sending to a queue, consuming it, `Ack` and `Retry` | [Queue](https://bynk-lang.org/book/guides/entry-points/queue/) |
| [`events`](events/) | declaring, emitting and subscribing to events | [Understand events](https://bynk-lang.org/book/guides/events/understand-events/) |
| [`localisation`](localisation/) | message bundles, ICU plurals, `Locale` negotiation | [Understand localisation](https://bynk-lang.org/book/guides/localisation/understand-localisation/) |
| [`concurrency`](concurrency/) | `par`, `race` and `within`, tested on virtual time | [Run calls at the same time](https://bynk-lang.org/book/guides/effects-and-capabilities/run-independent-calls-at-the-same-time/) |
| [`public-surface`](public-surface/) | a library's public surface: `private`, options records, `uses` | [Design a public surface](https://bynk-lang.org/book/guides/program-structure/design-a-public-surface/) |

## Running a project

[Install Bynk](https://bynk-lang.org/book/introduction/install/) at the
version in [`BYNK_VERSION`](BYNK_VERSION). Then, from a project's directory:

```sh
bynk test .      # run its tests
bynk dev          # serve it locally, if it has an HTTP context
```

## What counts as Bynkish here

CI holds every project to the same bar:

- **Canonical formatting.** `bynk fmt --check` passes, so the formatter's
  output is the house style.
- **It type-checks.** `bynk check` is clean.
- **The feature is tested.** `bynk test` exercises the feature the project
  is about, not just the code around it.
- **It's small.** A project shows one idea. If a project needs a second idea,
  that idea gets its own project.

## Compatibility

[`BYNK_VERSION`](BYNK_VERSION) pins the release CI checks against. The
[org canary](https://github.com/bynk-lang/.github/blob/main/canary/README.md)
re-runs every project against each new Bynk release. It opens a `canary`
issue if a project breaks, and a pull request moving the pin once a newer
release passes.

## Licence

Dual-licensed under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE), at
your option.
