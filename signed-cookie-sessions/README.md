# Signed-cookie sessions

A browser signs in once and is recognised on every later request by a session
cookie that Bynk issues and verifies itself. There's no token to mint
elsewhere and no session store to run.

## The idea

A `SignedCookie` actor is an authentication scheme like `Bearer` or `Oidc`, but
for a browser. It names the environment variable that holds the signing key,
how long a cookie lives, and the identity type the cookie carries:

```bynk
actor User { auth = SignedCookie(secret = "SESSION_KEY", ttl = 8.hours), identity = UserId }
```

Inside the context that declares it, `User.issue(id)` makes the cookie and
`User.expire()` clears it. A route guarded `by u: User` has the cookie verified
before its body runs, and gets `u.identity`, never the cookie: the session
cookie is hidden from the handler's `headers` and `cookies` too.

The scheme owns every attribute. The cookie is `__Host-session`, `Secure`,
`HttpOnly`, `SameSite=Lax`, `Path=/` and has no `Domain`, so it's bound to this
origin and out of reach of page scripts. Writing it by hand, as a `Cookie { … }`
literal, is refused.

A cookie the browser sends on its own is also a cookie another site can make
it send. So a state-changing route (`POST`, `PUT`, `PATCH`, `DELETE`) guarded
by a `SignedCookie` actor also checks where the request came from: the site's
own pages pass, and another origin passes only if the service's `cors` lists it
with `credentials: true`. Everything else is a `403`, cookie and all.

What it doesn't do: the cookie is signed, not encrypted, so never put a secret
in the identity. And it can't be revoked before its `ttl`: `expire()` clears
the browser's copy, not a copy someone already took. Keep the `ttl` short, or
keep sessions on the server if you need to sign someone out everywhere.

## Walkthrough

[`src/desk/site.bynk`](src/desk/site.bynk) has four routes. `/login` checks the
password first, through the `Accounts` capability, and only then issues the
cookie. The cookie proves who it was issued to, not that they should have it:

```bynk
let ok <- Accounts.verify(id, body.password)
if ok {
	let session <- User.issue(id)
	Ok("signed in as \(id)").withCookie(session)
} else {
	Unauthorized
}
```

Issuing stamps an expiry, so the handler is `given Clock`. `/me` and `/away`
are guarded `by u: User`, and `/logout` sends the cookie back expired.

`secret = "SESSION_KEY"` names a variable, not a key. `bynk deploy` mints a
strong key the first time and keeps it on later deploys, and `bynk dev` derives
a local one, so there's nothing to set up. To rotate it without signing
everyone out, add `previous = "SESSION_KEY_PREV"`.

[`tests/desk/site.bynk`](tests/desk/site.bynk) is the unit suite, where
`by User("ada")` hands a handler that identity. It checks that a good password
sets `__Host-session` with the safe attributes, a wrong one issues nothing, and
signing out sends it back with `Max-Age=0`.

[`tests/desk/seam.bynk`](tests/desk/seam.bynk) is a `system` suite, where the
driver sends a real signed cookie to the real Worker. The reserved principals
probe the seam: `by Nobody` sends no cookie, `by Forged` one signed with
another key, and `by Expired` one whose time is up. Request headers probe the
cross-site check:

```bynk
let r <- site.POST(
	"/away",
	RequestHeaders.of(["Sec-Fetch-Site: cross-site", "Origin: https://evil.example"])
) by User("ada")
expect r is Forbidden
```

## Run it

```sh
bynk test .
```

The tests stub `Accounts`. Its provider, `HttpAccounts`, asks an accounts
service at `ACCOUNTS_URL`, and treats anything but a `204`, an outage
included, as a wrong password: a sign-in check fails closed. See
[`capabilities-and-providers`](../capabilities-and-providers/) for the pattern.

## Read next

- [Authenticate a browser with a signed cookie](https://bynk-lang.org/book/guides/actors/authenticate-with-a-signed-cookie/)
- [Reference: what a signed cookie does and does not protect against](https://bynk-lang.org/book/reference/actors/#what-a-signed-cookie-does-and-does-not-protect-against)
- [Testing: the failure principals](https://bynk-lang.org/book/reference/testing/#failure-principals)
- Showcase: [`cookies`](../cookies/) for cookies a visitor may set and change,
  [`actors-and-authorisation`](../actors-and-authorisation/) for Bearer tokens,
  and [`oidc`](../oidc/) for signing in through an identity provider.
