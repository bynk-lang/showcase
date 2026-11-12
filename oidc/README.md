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
`repository` claim.

[`tests/ci/seam.bynk`](tests/ci/seam.bynk) is a `system` suite, which runs the
deployable Worker with its real auth seam. There the test driver is the issuer:
it generates a key pair, answers the Worker's fetch of the actor's `jwks` URL,
and mints each call's token. `by Workload(…)` presents a valid one, `Nobody`
sends no token at all, and four failure principals present one the seam must
refuse:

```bynk
let forged <- release.POST("/release") by Forged          // signed by a key the JWKS lacks
let expired <- release.POST("/release") by Expired        // `exp` an hour ago
let wrongIss <- release.POST("/release") by WrongIssuer   // another `iss`
let wrongAud <- release.POST("/release") by WrongAudience // another `aud`
expect forged is Rejected(Unauthorized)
```

Two more cover what OIDC checks most often get wrong. `by WrongAlgorithm`
presents a token with `alg: none` and one HS256-signed with the JWKS public key
as the secret. `by NoSubject` presents one with an empty `sub`, which couldn't
become a `NonEmpty` `WorkloadId`, and one with no `sub` at all, which carries no
identity. Each principal sends both its tokens, and the call is
`Rejected(Unauthorized)` only if both are refused; if the seam admits either,
the case sees that outcome and fails:

```bynk
let alg <- release.POST("/release") by WrongAlgorithm
let sub <- release.POST("/release") by NoSubject
expect alg is Rejected(Unauthorized)
expect sub is Rejected(Unauthorized)
```

Each token is a `401` before the handler runs. Only the test module holds the key, so
nothing in the deployed Worker trusts it.

## Run it

```sh
bynk test .
```

## Read next

- [Authenticate with OIDC / JWKS](https://bynk-lang.org/book/guides/actors/authenticate-with-oidc/)
- [Reference: Actors, reading claims](https://bynk-lang.org/book/reference/actors/#reading-claims)
- [Reference: Testing, passing token claims](https://bynk-lang.org/book/reference/testing/#token-claims)
- [Reference: Testing, an `Oidc` route at `system`](https://bynk-lang.org/book/reference/testing/#oidc-issuer)
- [`actors-and-authorisation`](../actors-and-authorisation/) for `Bearer` actors,
  refusals and authorisation invariants
