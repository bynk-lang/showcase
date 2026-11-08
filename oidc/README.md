# OIDC

A release endpoint that only CI jobs holding a valid identity-provider token may
call, and only from one trusted repository. It shows `Oidc` actors: tokens
verified against the provider's public keys, and the token's claims read in the
handler.

## The idea

An `Oidc` actor verifies an RS256/ES256 JWT from the `Authorization: Bearer`
header against the provider's published JWKS. It names three public values, the
`issuer`, the `audience` and the `jwks` URL, and no secret, so there is no
signing key to store, rotate or leak. The compiler emits the check at the
boundary: signature, `iss`, `aud` and `exp` must all hold, or the answer is a
`401` and the body never runs. The `sub` claim becomes the sealed identity.

Authenticating *who* is separate from deciding what they may do. The verified
claims reach the handler as `w.claims`, so a rule such as "only this repository"
is ordinary code over claims you can trust.

## Walkthrough

[`src/ci/release.bynk`](src/ci/release.bynk) is the whole service. The actor:

```bynk
actor Workload {
	auth = Oidc(
		issuer = "https://token.actions.example.com",
		audience = "release-api",
		jwks = "https://token.actions.example.com/.well-known/jwks"
	),
	identity = WorkloadId
}
```

The handler reads one claim as an `Option[String]` and keeps that string:

```bynk
on POST("/release") () -> Effect[HttpResult[String]] by w: Workload {
	match w.claims.get("repository") {
		Some("acme/money") => Ok("released by \(w.identity)")
		_ => Forbidden
	}
}
```

[`tests/ci/release.bynk`](tests/ci/release.bynk) is a unit suite. At that tier
the handler runs in process, and a case supplies the claims a verified token
would carry:

```bynk
let r <- release.POST("/release") by Workload("wid", TokenClaims.of(["repository: acme/money"]))
expect r == Ok("released by wid")
```

The cases cover the trusted repository, another repository, and a token with no
`repository` claim. The signature, issuer, audience and expiry checks live in the
auth seam, which the driver can't exercise yet: a `system` case can't call an
`Oidc` route, because the driver holds no key pair for the JWKS
(`bynk.test.oidc_needs_in_process`). To drive the real seam, point the actor at
a fake issuer with `trustFrom`.

## Run it

```sh
bynk test .
```

## Read next

- [Authenticate with OIDC / JWKS](https://bynk-lang.org/book/guides/actors/authenticate-with-oidc/)
- [Reference: Actors, reading claims](https://bynk-lang.org/book/reference/actors/#reading-claims)
- [Reference: Testing, passing token claims](https://bynk-lang.org/book/reference/testing/#token-claims)
- [`actors-and-authorisation`](../actors-and-authorisation/) for `Bearer` actors,
  refusals and authorisation invariants
