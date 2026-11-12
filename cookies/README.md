# Cookies

A site that remembers a visitor's theme and counts their visits, in cookies.
Cookies are read through a typed record, checked at the boundary like a query
or a body, and set with safe defaults.

## The idea

A handler that takes `cookies: T` gets the request's `Cookie` header decoded
into the record `T` before it runs: refinements, defaults and `Option`s apply,
and a value that doesn't fit is a `400` naming the cookie (`cookies.theme`).
Cookies the record doesn't name, such as an analytics cookie, are ignored.

Setting a cookie is a method on the result, `withCookie(Cookie { … })`. A
`Cookie` record starts from the safe attributes: `Secure`, `HttpOnly`,
`SameSite=Lax`, `Path=/`, and no `Domain`. Turning one of them off in a literal
is refused or warned about, as is a `__Host-` cookie that breaks the prefix's
rules. `clearCookie` sends the same cookie back empty and already expired,
which is how a browser forgets one.

A cookie arrives from the client, so it's input like any other, never proof of
who's asking. That's why `visits` is only a count.

Strict decoding has a cost to plan for: a stored cookie that no longer decodes
refuses every route that reads it, for as long as the browser keeps it. Rename
`Dark` and everyone who chose dark mode gets a `400` on `/theme` and `/visit`
until the year-long cookie expires. Treat a cookie's type like a stored schema,
and change it compatibly: add variants and defaulted fields, don't rename or
remove them.

## Walkthrough

[`src/prefs/site.bynk`](src/prefs/site.bynk) declares the cookies it reads:

```bynk
type Prefs = {
	theme: Theme = Light,
	@name("__Host-visits") visits: Int = 0,
}
```

A first visit sends no cookies, so both fields have defaults. The visit count
is a `__Host-` cookie, which the browser only accepts from this exact host over
HTTPS, so a sibling subdomain can't plant one. `__Host-visits` isn't a valid
field name, so `@name` gives the field the key the browser sends.

The handlers read `cookies.theme` and `cookies.visits` like any record, and set
cookies on the way out:

```bynk
on GET("/visit") (cookies: Prefs) -> Effect[HttpResult[String]] by Visitor {
	let n = cookies.visits + 1
	Ok("visit \(n)").withCookie(Cookie { name: "__Host-visits", value: "\(n)" })
}
```

[`tests/prefs/site.bynk`](tests/prefs/site.bynk) is the unit suite. A handler
gets its `Prefs` directly there, and `r.cookies()` reads the cookies a result
sets: the theme cookie's name and value, that it's `secure` and `httpOnly`
without asking, that a reset sends it back empty, and that a visit sends the
new count.

[`tests/prefs/boundary.bynk`](tests/prefs/boundary.bynk) is a `system` suite,
where the router parses the header. A `Wire(…)` argument is the header text a
browser would send:

```bynk
let counted <- site.GET("/visit", Wire("__Host-visits=4"))
let unprefixed <- site.GET("/visit", Wire("visits=4"))
expect counted is Handled(Ok("visit 5"))
expect unprefixed is Handled(Ok("visit 1"))
```

The other cases: no cookies takes the defaults, an unrelated cookie is ignored,
and `theme=Purple` is refused before the handler runs.

## Run it

```sh
bynk test .
bynk dev
```

## Read next

- [Cookies](https://bynk-lang.org/book/reference/http/#cookies), including
  [prefixed cookies](https://bynk-lang.org/book/reference/http/#request-cookies)
- [Testing: sending cookies](https://bynk-lang.org/book/reference/testing/#sending-cookies)
  and [reading the cookies a result sets](https://bynk-lang.org/book/reference/testing/#result-cookies)
- Showcase: [`actors-and-authorisation`](../actors-and-authorisation/) for
  authenticating a caller, which a cookie alone doesn't do, and
  [`forms`](../forms/) for the other half of a classic web page.
