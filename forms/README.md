# Forms

A newsletter sign-up and a photo upload, posted from plain HTML forms. `@form`
and `@multipart` decode the body into a typed record at the boundary, so the
handler gets a valid `SignupForm` or `PhotoForm`, never form text.

## The idea

A browser's `<form method="post">` doesn't send JSON. It sends
`application/x-www-form-urlencoded` text, or `multipart/form-data` when a file
is chosen. Annotating the handler says which:

- **`@form`** decodes `email=ada%40example.com&topics=News&topics=Events` into a
  record, with the same refinements, defaults and `Option`s as a JSON body. A
  value that breaks a refinement is a `400` naming the field (`body.email`),
  before the handler runs.
- **`@multipart`** does the same for an upload, with each file part as a
  `File`: `filename`, `contentType` and the `bytes`. The body is held in memory,
  so the route must have a cap.

A form isn't JSON, and the rules follow what browsers actually send:

- An input left empty arrives as `name=`. For an `Option` that's `None`.
- A group of checkboxes with one name repeats the key, which fills a `List`.
- An unticked checkbox sends nothing at all, so a `Bool` needs a default
  (`weekly: Bool = false`).
- Keys are flat: a field is a `String`, `Int`, `Bool`, `Decimal`, an enum or a
  refined type over one, never a nested record.

## Walkthrough

[`src/newsletter/site.bynk`](src/newsletter/site.bynk) declares the two forms
and the service. The sign-up form:

```bynk
type SignupForm = {
	email: Email,
	name: Option[String],
	topics: List[Topic] = [],
	weekly: Bool = false,
}
```

The handlers say which wire format their body has. `limits { }` caps the body
and each file part, which a `@multipart` route requires:

```bynk
limits {
	maxBody: 1_000_000,
	maxFile: 500_000,
}

@form
on POST("/subscribe") (body: SignupForm) -> Effect[HttpResult[String]] by Visitor {
	Ok(confirmation(body))
}
```

A `File`'s `filename` and `contentType` are whatever the client claimed, so the
upload handler uses only the bytes.

[`tests/newsletter/site.bynk`](tests/newsletter/site.bynk) is the unit suite.
A handler gets its record directly there, so the decoding rules are tested
through `Form.decode` and `Form.encode`, the `@form` mapping as a codec:
repeated checkboxes fill the list, an empty input is `None`, missing fields
take their defaults, a bad address fails at `$.email`, and an encoded form
decodes back to itself.

[`tests/newsletter/boundary.bynk`](tests/newsletter/boundary.bynk) is a
`system` suite, where the router does the decoding. A `Wire(…)` body sends the
exact text a browser would:

```bynk
let r <- site.POST("/subscribe", Wire("email=nope"))
expect r is Rejected(RefinementViolation(_))
```

A form post is a simple request in CORS terms, so another site's page can
submit to this route. Nothing here authenticates the submitter: a real sign-up
would confirm the address before it counted.

## Run it

```sh
bynk test .
bynk dev
```

Then post a form as a browser would:

```sh
curl localhost:8787/subscribe -d 'email=ada%40example.com&topics=News&weekly=on'
curl localhost:8787/photos -F caption=Tom -F photo=@cat.jpg
```

## Read next

- [Form bodies](https://bynk-lang.org/book/reference/http/#form-bodies) and
  [multipart bodies](https://bynk-lang.org/book/reference/http/#multipart-bodies)
- [`Form.decode` and `Form.encode`](https://bynk-lang.org/book/reference/types/#form-codec)
- [Testing: sending a form](https://bynk-lang.org/book/reference/testing/#sending-a-form)
- Showcase: [`serve-a-page`](../serve-a-page/) for the page a form lives in,
  [`decode-json`](../decode-json/) for the same typed decode over JSON and YAML,
  and [`files-in-r2`](../files-in-r2/) for where uploaded bytes can go.
