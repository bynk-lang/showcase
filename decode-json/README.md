# Decode JSON

`Json.decode[T](text)` turns untrusted JSON into a typed value, or a typed error.
This project decodes a sign-up form: a refined name, a refined age and an optional
note.

## The idea

JSON from outside is just text. `Json.decode[Signup](raw)` checks it against the
type and returns `Result[Signup, DecodeError]`. The check covers the shape (fields
and base types) and every refinement, so an `Ok` value is already valid and no
separate `.of` step is needed. A failure is a `DecodeError` with three `String`
fields: `kind` (`Malformed`, `StructuralMismatch` or `RefinementViolation`), `path`
(such as `$.age`) and `message`.

## Walkthrough

**`src/intake/signup.bynk`** declares the type. The predicates sit in the fields:

```bynk
type Name = String where NonEmpty

type Age = Int where InRange(13, 120)

type Signup = {
	name: Name,
	age: Age,
	note: Option[String],
}
```

Decoding is one call. The type argument is required:

```bynk
fn parse(raw: String) -> Result[Signup, DecodeError] {
	Json.decode[Signup](raw)
}
```

`DecodeError` has no string form, so a report interpolates its fields:

```bynk
Err(e) => "\(e.kind) at \(e.path): \(e.message)"
```

`note` is an `Option`, the one field that may be missing. Absent, `null` and a bare
value all decode. `Json.encodePlain` writes the other way for a non-Bynk API, with
`None` as `null` (plain `Json.encode` uses Bynk's tagged form):

```bynk
fn render(s: Signup) -> String {
	Json.encodePlain(s)
}
```

The same type decodes from YAML. `Yaml.decode[T]` reads a safe subset of YAML
1.2 (no anchors, aliases, merge keys or tags, one document, bounded size and
nesting) and passes the result to the same typed decode, so a `Signup` from a
config file is checked exactly as one from a request:

```bynk
fn fromYaml(raw: String) -> Result[Signup, DecodeError] {
	Yaml.decode[Signup](raw)
}
```

A YAML refusal is a `DecodeError` too, with its own `kind`, such as
`UnsupportedAnchor`, and a `message` ending in the line and column.

**`tests/intake/signup.bynk`** feeds in bad text and checks the `kind` of each
failure: malformed JSON, a missing field or wrong base type, and an empty name or
out-of-range age. It also checks that the error path names `$.age`, and that
`encodePlain` output decodes back. The YAML cases decode the same `Signup`, hit
the same refinement at the same path, and show an anchor refused.

## Run it

```sh
bynk test .
```

## Read next

- [Decode untrusted JSON into a typed value](https://bynk-lang.org/book/guides/type-system/decode-json/)
- [The JSON codec](https://bynk-lang.org/book/reference/types/#the-json-codec)
- Sibling projects: [refined-types](../refined-types/) and
  [results-and-optionals](../results-and-optionals/).
