-- STRICT makes SQLite hold each column to its declared type, and the CHECKs
-- repeat `Book`'s refinements, so no writer can store a row `Book` refuses.
CREATE TABLE books (
	isbn TEXT PRIMARY KEY CHECK (length(isbn) > 0),
	title TEXT NOT NULL CHECK (length(title) > 0),
	author TEXT NOT NULL CHECK (length(author) > 0),
	pages INTEGER NOT NULL CHECK (pages > 0),
	finished INTEGER NOT NULL DEFAULT 0 CHECK (finished IN (0, 1))
) STRICT;
