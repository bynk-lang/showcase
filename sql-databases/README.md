# SQL databases

A reading list kept in a Cloudflare D1 database. The schema lives in a
migration, the statements are SQL written inline as tagged `"""sql` strings,
and reads come back as a typed `Book` record through `select[T]` and
`firstAs[T]`. A small HTTP service sits in front.

## The idea

A `D1` capability is a SQLite database. You declare one by name,
`capability Books = D1`. Its schema is a numbered SQL file in `migrations/`, so
the shape of the table lives in one place and every test case starts with it
applied.

Three rules keep the SQL safe and the rows typed:

- **The SQL is a literal.** Every statement is a string literal, so request
  data reaches it only as a bound parameter (`?1`, `Text(isbn)`). A variable or
  an interpolated string is `bynk.types.sql_not_literal`. A long statement
  reads best as a multi-line string, and the `sql` tag after the opening
  `"""` tells editors to highlight it as SQL. The tag is not part of the
  value.
- **The row is a record.** `select[Book]` and `firstAs[Book]` write
  `SELECT "isbn", "title", …` from `Book`'s fields, so you write the statement
  from `FROM` on and the column list is never spelt twice.
- **Failure is a value.** A statement never throws. A write gives
  `Result[SqlRun, SqlError]`, where `Constraint` is a broken key or `CHECK`
  that a handler can answer. A typed read gives `SqlReadError`: `Sql(e)` when
  the statement failed, `Decode(e)` when a row didn't fit the record. In each
  arm `e` has its own type (`SqlError` or `JsonError`), so the handler can say
  exactly what went wrong.

## Walkthrough

[`migrations/shelf-library-books/0001_create_books.sql`](migrations/shelf-library-books/0001_create_books.sql)
creates the `books` table. The directory is named after the database, which
Bynk derives from the context and the capability: `shelf.library`'s `Books` is
`shelf-library-books`.

[`src/shelf/books.bynk`](src/shelf/books.bynk) holds `Book`, the row type. Its
fields are named exactly like the columns. `finished` is stored as `0` or `1`,
because SQLite has no boolean, and a typed read takes those as a `Bool`.

[`src/shelf/library.bynk`](src/shelf/library.bynk) is the service. An insert
is a tagged multi-line statement with five bound parameters, and a duplicate
ISBN breaks the primary key, which becomes a `409`:

```bynk
let added <- Books.run(
	"""sql
	INSERT INTO books (isbn, title, author, pages, finished)
	VALUES (?1, ?2, ?3, ?4, ?5)
	""",
	[
		Text(body.isbn),
		Text(body.title),
		Text(body.author),
		Integer(body.pages),
		Boolean(body.finished),
	]
)
match added {
	Ok(_) => Created(body),
	Err(Constraint(_)) => Conflict("that ISBN is already on the shelf"),
	Err(e) => ServerError(sqlReason(e)),
}
```

The unread list reads every matching row into a `List[Book]`. The statement
starts at `FROM`. In the error arms, `e` is a `SqlError` in one and a
`JsonError` in the other, and each goes to a function typed at it:

```bynk
let rows <- Books.select[Book](
	"""sql
	FROM books
	WHERE finished = 0
	ORDER BY pages, title
	""",
	[]
)
match rows {
	Ok(list) => Ok(list),
	Err(Sql(e)) => ServerError(sqlReason(e)),
	Err(Decode(e)) => ServerError(rowReason(e)),
}
```

`GET /books/:isbn` uses `firstAs[Book]`, which gives `Option[Book]`, so no
matching row is `NotFound`. Marking a book read is an `UPDATE`, and its
`SqlRun.changes` tells a missing book (`0` rows changed) from a found one.
`SqlError` is extensible, so `sqlReason`'s match keeps a wildcard.

[`tests/shelf/library.bynk`](tests/shelf/library.bynk) runs against a real
in-memory SQLite database, with the migration applied. The first case reads
before writing anything, which shows the schema is already there. The two
error cases reach under the service: a case can call `Books` directly. One
stores the text `'n/a'` in the `INTEGER` `pages` column, which SQLite allows,
and the read reports a `Decode` error at `$.pages`. The other drops the table,
and the read reports a `Sql` error.

## Run it

```sh
bynkc test .
bynk dev
```

With `bynk dev` running, `POST /books` adds a book, `GET /unread` lists the
ones still to read, and `POST /books/:isbn/finished` marks one read.

## Read next

- [Query rows into a record](https://bynk-lang.org/book/guides/effects-and-capabilities/query-rows-into-a-record/):
  `select[T]` and `firstAs[T]`, step by step.
- [SQL databases: `D1`](https://bynk-lang.org/book/reference/bynk-capabilities/#sql-databases-d1):
  every operation, `SqlValue`, `SqlError`, `batch`, and
  [schema migrations](https://bynk-lang.org/book/reference/bynk-capabilities/#schema-migrations).
- [`storage-and-queries`](../storage-and-queries/): state kept in an agent
  rather than a database, read with `Query[T]`.
- [`results-and-optionals`](../results-and-optionals/): the `Result` and
  `Option` values every statement returns.
