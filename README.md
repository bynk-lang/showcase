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
| [`sql-databases`](sql-databases/) | a D1 database: migrations, `"""sql` statements, typed reads with `select[T]` and `firstAs[T]`, SQL checked against the schema at compile time, `Sql` and `Decode` errors | [Query rows into a record](https://bynk-lang.org/book/guides/effects-and-capabilities/query-rows-into-a-record/) |
| [`postgres`](postgres/) | an existing Postgres database through Hyperdrive: `$n` parameters, typed reads, an all-or-none `transaction`, and tests on PGlite (experimental) | [Connect an existing Postgres database](https://bynk-lang.org/book/guides/effects-and-capabilities/connect-an-existing-postgres-database/) |
| [`testing`](testing/) | tests in the language: stubs, platform doubles, fixtures | [Write tests](https://bynk-lang.org/book/guides/testing/write-tests/) |
| [`mutation-testing`](mutation-testing/) | `bynk test --mutate`: would the suite notice if the code were wrong? A rule whose every mutant is killed | [Run your tests](https://bynk-lang.org/book/guides/testing/run-tests/) |
| [`function-contracts`](function-contracts/) | `requires` and `ensures` on a pure function, checked at every call and attacked by the test runner, and the `dev` and `release` profiles | [Contracts](https://bynk-lang.org/book/reference/testing/#contracts) |
| [`actors-and-authorisation`](actors-and-authorisation/) | public and authenticated routes, claim checks, an agent keyed by the caller | [Authorisation](https://bynk-lang.org/book/guides/actors/authorisation/) |
| [`verify-webhooks`](verify-webhooks/) | signed webhooks verified for you; signing your own data | [Verify webhooks](https://bynk-lang.org/book/guides/actors/verify-webhooks/) |
| [`scheduled-jobs`](scheduled-jobs/) | cron handlers, driven from tests at a chosen time | [Cron](https://bynk-lang.org/book/guides/entry-points/cron/) |
| [`queues`](queues/) | sending to a queue, consuming it, `Ack` and `Retry` | [Queue](https://bynk-lang.org/book/guides/entry-points/queue/) |
| [`events`](events/) | declaring, emitting and subscribing to events | [Understand events](https://bynk-lang.org/book/guides/events/understand-events/) |
| [`evolving-a-contract`](evolving-a-contract/) | one context calling another, tested across the real wire, and a request field added with a default so the callee can deploy first | [Contract skew](https://bynk-lang.org/book/guides/projects-build-and-deployment/contract-skew/) |
| [`localisation`](localisation/) | message bundles, ICU plurals, `Locale` negotiation | [Understand localisation](https://bynk-lang.org/book/guides/localisation/understand-localisation/) |
| [`concurrency`](concurrency/) | `par`, `race` and `within`, tested on virtual time | [Run calls at the same time](https://bynk-lang.org/book/guides/effects-and-capabilities/run-independent-calls-at-the-same-time/) |
| [`public-surface`](public-surface/) | a library's public surface: `private`, options records, `uses` | [Design a public surface](https://bynk-lang.org/book/guides/program-structure/design-a-public-surface/) |
| [`decode-json`](decode-json/) | `Json.decode[T]` and `Yaml.decode[T]` turn untrusted text into a validated, refined value or a typed `DecodeError`, and `Json.encodePlain` writes it back out | [Decode untrusted JSON](https://bynk-lang.org/book/guides/type-system/decode-json/) |
| [`money`](money/) | exact `Decimal` money: refined `Price` and `Rate`, half-even tax, and splitting a total without losing a cent | [Handle money correctly](https://bynk-lang.org/book/guides/type-system/handle-money-correctly/) |
| [`rate-limiting`](rate-limiting/) | refusing a caller with `429`: the experimental `RateLimit` capability, `allow(key)`, tested with the in-memory limiter and `advance Clock` | [Rate-limit a route](https://bynk-lang.org/book/guides/effects-and-capabilities/rate-limit-a-route/) |
| [`files-in-r2`](files-in-r2/) | R2 object storage: a write-once upload, a download, and a prefix listing, tested on the in-memory double | [Store files in R2](https://bynk-lang.org/book/guides/effects-and-capabilities/store-files-in-r2/) |
| [`serve-a-page`](serve-a-page/) | keeping markup in an `.html` embed, filling it in, and serving it as a `Raw` HTML response | [Serve a page](https://bynk-lang.org/book/guides/entry-points/serve-a-page/) |
| [`forms`](forms/) | `@form` and `@multipart` decode an HTML form post or an upload into a typed record at the boundary; `Form.decode` and `Form.encode` | [Form bodies](https://bynk-lang.org/book/reference/http/#form-bodies) |
| [`cookies`](cookies/) | reading cookies through a typed record checked at the boundary, `@name` for a `__Host-` cookie, and setting and clearing cookies with safe defaults | [Cookies](https://bynk-lang.org/book/reference/http/#cookies) |
| [`oidc`](oidc/) | `Oidc` actors verify an identity provider's tokens against its public JWKS, and a handler reads the verified claims | [Authenticate with OIDC](https://bynk-lang.org/book/guides/actors/authenticate-with-oidc/) |
| [`websocket`](websocket/) | accepting a WebSocket upgrade authenticated at the edge, handing the `Connection` to an agent, and broadcasting to a room, tested against a `TestConnection` | [Handle a WebSocket connection](https://bynk-lang.org/book/guides/entry-points/websocket/) |

## Running a project

[Install Bynk](https://bynk-lang.org/book/introduction/install/) at the
version in [`BYNK_VERSION`](BYNK_VERSION). Then, from a project's directory:

```sh
bynk test .      # run its tests
bynk dev          # serve it locally, if it has an HTTP context
```

The repository root is a [workspace](https://bynk-lang.org/book/guides/projects-build-and-deployment/layout/#workspaces)
([`bynk.toml`](bynk.toml)), so from the root `bynk test .`, `bynk check .` and
`bynk fmt .` run over every project in turn, each with its own settings (the
`.` is optional: it's the default path). `bynk dev` and `bynk deploy` run one
project, so use them from its directory.

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
