# Postgres

A depot's stock, kept in a Postgres database that already exists, reached from
a Worker through Cloudflare Hyperdrive. Statements are SQL literals with `$n`
parameters, typed reads decode rows into records, and a transaction applies a
list of statements all or none. `Postgres` is **experimental** in Bynk.

## The idea

[`sql-databases`](../sql-databases/) owns its D1 database: its migrations are
the schema. A Postgres database is usually someone else's, and Bynk doesn't own
its schema. What it adds is at the edges:

- **Every value is a parameter.** The SQL is a string literal, and values go in
  as `PgText(…)`, `PgInteger(…)` and so on against `$1`, `$2`, so request data
  never becomes SQL text.
- **Rows decode into records.** `select[Item]("FROM stock …")` writes the column
  list from `Item`'s fields and decodes each row, a `bigint` into an `Int` and a
  `timestamptz` into an `Instant`.
- **Failure is a value.** An operation answers a `PgError` (`PgConstraint` with
  its SQLSTATE, `PgConnection`, `PgFailed` …), never a thrown exception.
- **A `schema.sql` switches on checks.** `bynk check` counts each literal
  statement's placeholders against its list (an error) and parses it (a
  warning). It doesn't check names against your tables.

## Walkthrough

[`bynk.toml`](bynk.toml) opts in to the experimental capability, and to running
tests against [PGlite](https://pglite.dev/), Postgres compiled to WebAssembly:

```toml
[unstable]
allow = ["bynk.cloudflare.Postgres"]

[test]
postgres = "pglite"
```

[`schema.sql`](schema.sql) mirrors the database's two tables. `stock` has a
`CHECK (qty >= 0)` and `orders` a foreign key to it, so the database itself
refuses an order it can't fill.

[`src/depot/stock.bynk`](src/depot/stock.bynk) declares the database as a named
instance, bound as `HYPERDRIVE_MAIN`:

```bynk
capability Main = Postgres
```

An order is two statements that must happen together:

```bynk
let done <- Main.transaction([
	PgStatement {
		sql: "INSERT INTO orders (sku) VALUES ($1)",
		params: [PgText(sku)],
	},
	PgStatement {
		sql: "UPDATE stock SET qty = qty - 1 WHERE sku = $1",
		params: [PgText(sku)],
	},
])
```

The order goes in first, so a refused decrement has something to undo. If the
decrement would go below zero, the `CHECK` refuses it and the transaction rolls
the order back. If the SKU doesn't exist, the order's foreign key refuses it
straight away; without that key, an unknown SKU would be "ordered", because an
`UPDATE` that matches no rows succeeds. Either way the statement fails with
`PgConstraint`, nothing is recorded, and the handler answers `409`.

[`tests/depot/stock.bynk`](tests/depot/stock.bynk) runs on PGlite: each case
starts from an empty database with `schema.sql` applied, so the `CHECK`, the
foreign key and the rollback all happen for real. One case counts the orders
after a refused second order, calling `Main.first` directly, and finds just
the first: the second's row was inserted and then rolled back. A `stub` still answers before the
database, which is how the last case forces a `PgConnection` outage.

## Run it

```sh
bynk test .
```

The first run installs PGlite, about 27 MB, and starting it adds about 1.5
seconds per run.

To run or deploy it against a real database, name the environment variables
that hold each connection string in `bynk.toml`. The strings are secrets, so
they never go in a committed file:

```toml
[dev.hyperdrive.Main]
connection_env = "MAIN_LOCAL_DATABASE_URL"

[deploy.hyperdrive.Main]
connection_env = "MAIN_DATABASE_URL"
```

`bynk deploy` then creates and syncs the Hyperdrive configuration itself. The
build's `package.json` names the `postgres` driver: run `npm install` in the
build directory first.

## Read next

- [Connect an existing Postgres database](https://bynk-lang.org/book/guides/effects-and-capabilities/connect-an-existing-postgres-database/)
- [Postgres reference](https://bynk-lang.org/book/reference/bynk-capabilities/#postgres-databases-postgres)
- [Postgres under test](https://bynk-lang.org/book/reference/testing/#postgres-under-test)
- Showcase: [`sql-databases`](../sql-databases/) for a D1 database whose
  schema the project owns. A MySQL or MariaDB database works the same way
  through `MySql`.
