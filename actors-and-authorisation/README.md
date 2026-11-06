# Actors and authorisation

A blog's author bios, behind a tiny HTTP service. Anyone may read a bio, a
signed-in author may write their own, and only a moderator may clear one. It
shows Bynk's actors: who may call each route, checked at the boundary before a
handler runs, and an agent keyed by the caller's verified identity.

## The idea

Every HTTP handler names its caller with a `by` clause, even a public one
(`by Visitor`). There is no unguarded default to forget. An actor declares how a
caller is verified (here a `Bearer` JWT) and which type its identity becomes.
The compiler emits the verification and fails closed: a missing, forged or
expired token is a `401` and the body never runs.

A refinement actor (`Moderator = Author where hasClaim("moderator")`) adds an
authorisation rule on top. A valid token without the claim is a `403`, so "who
are you?" stays distinct from "you may not".

The handler sees only a sealed identity, `a.identity`. Using it as an agent key
means a write can only ever reach the caller's own data. There's no `userId`
parameter for a client to forge, and no ownership check to forget.

## Walkthrough

[`src/blog/authors.bynk`](src/blog/authors.bynk) is the whole service. The two
actors:

```bynk
actor Author { auth = Bearer(secret = "AUTH_JWT_SECRET"), identity = UserId }
```

```bynk
actor Moderator = Author where hasClaim("moderator")
```

The service header sets `by Visitor` as the default, so the `GET` is public. The
write overrides it, and keys the `Bios` agent by the verified handle:

```bynk
on PUT("/me/bio") (body: BioUpdate) -> Effect[HttpResult[Bio]] by a: Author {
	do Bios(a.identity).write(body.bio)
	Ok(body.bio)
}
```

The moderator route only gates on the claim, so it names the actor with no
binder:

```bynk
on DELETE("/authors/:id/bio") (id: UserId) -> Effect[HttpResult[String]] by Moderator {
	do Bios(id).clear()
	NoContent
}
```

[`tests/blog/authors.bynk`](tests/blog/authors.bynk) is a unit suite. A call's
`by Author("ada")` gives the identity, and the cases show each caller doing what
it may, including that bob's write lands on bob's bio and not on ada's.

[`tests/blog/seam.bynk`](tests/blog/seam.bynk) is the same service `as system`.
Below that tier the auth seam is skipped, so the refusals can only be tested
here. Each call goes through the real Worker, with credentials the seam must
turn away:

```bynk
let none <- api.PUT("/me/bio", BioUpdate { bio: "Anonymous." }) by Nobody
let forged <- api.PUT("/me/bio", BioUpdate { bio: "Forged." }) by Forged
let expired <- api.PUT("/me/bio", BioUpdate { bio: "Expired." }) by Expired
expect none is Rejected(Unauthorized)
expect forged is Rejected(Unauthorized)
expect expired is Rejected(Unauthorized)
```

An author acting on the moderator route gets `Forbidden`, and a moderator gets
`NoContent`.

## Run it

```sh
bynkc test .
bynk dev -- --var AUTH_JWT_SECRET:dev-only-secret
```

Then, in another terminal, write a bio as `ada` and read it back:

```sh
export AUTH_JWT_SECRET=dev-only-secret
curl -X PUT -H "Authorization: Bearer $(bynk token Author --sub ada)" \
  -H "Content-Type: application/json" -d '{"bio":"Writes about type systems."}' \
  http://localhost:8787/me/bio
curl http://localhost:8787/authors/ada/bio
```

A refinement actor's token carries the claims its predicate needs, so
`bynk token Moderator` mints one with `moderator` set. Clear `ada`'s bio as a
moderator:

```sh
curl -X DELETE -H "Authorization: Bearer $(bynk token Moderator --sub mo)" \
  http://localhost:8787/authors/ada/bio
```

An `Author` token, which has no `moderator` claim, gets a `403` from the same
route.

## Read next

- [Serve public and authenticated routes](https://bynk-lang.org/book/guides/actors/public-and-authenticated/)
- [Add an authorisation invariant](https://bynk-lang.org/book/guides/actors/authorisation/)
- [Serve several kinds of caller from one route](https://bynk-lang.org/book/guides/actors/multiple-callers/)
- [Authenticate with OIDC / JWKS](https://bynk-lang.org/book/guides/actors/authenticate-with-oidc/)
- [Reference: Actors](https://bynk-lang.org/book/reference/actors/)
- [Reference: Testing, acting as an actor](https://bynk-lang.org/book/reference/testing/#call-site-by)
  and [the failure principals](https://bynk-lang.org/book/reference/testing/#failure-principals)
- [`agent-state-machine`](../agent-state-machine/), [`testing`](../testing/)
  and [`verify-webhooks`](../verify-webhooks/)
