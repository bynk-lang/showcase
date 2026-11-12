-- The database already exists and Bynk doesn't own it: this file mirrors its
-- schema. Each test case starts from it, and `bynk check` uses it to switch on
-- a syntax and placeholder check of every literal statement.
CREATE TABLE stock (
	sku text PRIMARY KEY CHECK (length(sku) > 0),
	qty integer NOT NULL CHECK (qty >= 0)
);

CREATE TABLE orders (
	id serial PRIMARY KEY,
	sku text NOT NULL REFERENCES stock (sku),
	placed timestamptz NOT NULL DEFAULT now()
);
