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

**`tests/intake/signup.bynk`** feeds in bad text and checks the `kind` of each
failure: malformed JSON, a missing field or wrong base type, and an empty name or
out-of-range age. It also checks that the error path names `$.age`, and that
`encodePlain` output decodes back.

## Run it

```sh
bynk test .
```

## Read next

- [Decode untrusted JSON into a typed value](https://bynk-lang.org/book/guides/type-system/decode-json/)
- [The JSON codec](https://bynk-lang.org/book/reference/types/#the-json-codec)
- Sibling projects: [refined-types](../refined-types/) and
  [results-and-optionals](../results-and-optionals/).
