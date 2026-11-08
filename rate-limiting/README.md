# Rate limiting

A search route that refuses a caller who asks too often, with a `429`. The
count comes from the experimental `RateLimit` capability, so the service keeps
no counters of its own.

`RateLimit` is **experimental**: it carries no compatibility promise yet.

## The idea

Abuse control wants a fast check that needs no storage. Declare a limiter as a
named instance of `RateLimit`, say how many calls a key may make and over what
window, ask it `allow(key)` in the handler, and answer `TooManyRequests` when it
says no. On Cloudflare it is backed by the Rate Limiting binding. The count is
approximate (it is kept per location), so use it for abuse and cost control, not
for an exact quota.

## Walkthrough

1. **`bynk.toml`** opts in to the experimental capability:

   ```toml
   [unstable]
   allow = ["bynk.cloudflare.RateLimit"]
   ```

2. **`src/search/api.bynk`** declares the limiter, three calls per key in each
   ten seconds, and the handler that asks it. A bare `given RateLimit` is
   refused, because it would set neither number:

   ```bynk
   capability SearchLimit = RateLimit @limit(3) @period(10.seconds)
   ```

   ```bynk
   	on GET("/search/:token") (token: String) -> Effect[HttpResult[String]] by Visitor given SearchLimit {
   		let allowed <- SearchLimit.allow(token)
   		if allowed {
   			Ok("results")
   		} else {
   			TooManyRequests("slow down: 3 searches per 10 seconds")
   		}
   	}
   ```

   The key is whatever identifies the caller to you; here it is the token.

3. **`tests/search/api.bynk`** exercises the limiter itself. In a test each
   limiter counts calls per key in memory, on the harness clock, so the fourth
   call is refused, another key is unaffected, and `advance Clock` reopens the
   window:

   ```bynk
   	advance Clock by 10.seconds
   	let again <- api.GET("/search/:token", "ann") by Visitor
   	expect again is Ok(_)
   ```

   To test only the refusal path, stub the limiter:
   `stub SearchLimit.allow(_) returns false`.

## Run it

```sh
bynk test .
```

## Read next

- [Rate-limit a route](https://bynk-lang.org/book/guides/effects-and-capabilities/rate-limit-a-route/)
- [`RateLimit` reference](https://bynk-lang.org/book/reference/bynk-capabilities/#rate-limiting-ratelimit)
- [HTTP reference: `TooManyRequests`](https://bynk-lang.org/book/reference/http/#4xx-client-error)
- For an exact limit, use an agent per key, as the rate limiter example does.
