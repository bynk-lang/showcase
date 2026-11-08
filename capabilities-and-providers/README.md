# Capabilities and providers

A tiny weather service that shows Bynk's capability model. The app declares the
capability it needs, `Forecasts`. A provider builds that capability over the
platform's `Fetch` and `Secrets`. The HTTP handler is given only `Forecasts`, so
its signature says exactly what it touches, and the tests swap the provider for a
stub and run offline.

## The idea

In Bynk, code reaches the outside world only through **capabilities** it is
granted. A capability is a typed contract with no bodies. A **provider**
implements it. A handler lists what it needs in a **`given`** clause, and it can
call nothing else. First-party capabilities such as `Fetch`, `Secrets` and
`Logger` come from `consumes bynk { … }`.

Declaring your *own* capability on top of those is what keeps dependencies
visible and swappable:

- **Visible.** `given Forecasts, Logger` on the handler is the whole list of its
  effects. That it uses HTTP and a secret is the provider's business, and the
  provider's own `given Fetch, Secrets` says so.
- **Swappable.** The composition root wires `Fetch` and `Secrets` into
  `HttpForecasts` for you. A test (or a different provider) replaces
  `Forecasts` and the handler doesn't change.

## Walkthrough

1. **`src/weather/forecast.bynk`** is a `commons` unit of pure types: a refined
   `City`, the `Forecast` record, and `advice`, which needs no capability at all.
2. **`src/weather/api.bynk`** is the `context`. It consumes the platform
   capabilities and declares the app's own:

   ```bynk
   consumes bynk { Fetch, Logger, Secrets }
   ```

   ```bynk
   capability Forecasts {
   	fn today(city: City) -> Effect[Result[Forecast, ForecastError]]
   }
   ```

   The provider composes `Forecasts` over two platform capabilities. It reads
   the base URL from `Secrets`, calls `Fetch`, and turns HTTP statuses into the
   domain's `ForecastError`:

   ```bynk
   provides Forecasts = HttpForecasts given Fetch, Secrets {
   ```

   The handler sees only the domain capability, plus `Logger` for one warning:

   ```bynk
   on GET("/forecast/:city") (
   	city: String
   ) -> Effect[HttpResult[String]] by Visitor given Forecasts, Logger {
   ```

3. **`tests/weather/api.bynk`** stubs `Forecasts` to drive every branch of the
   handler, and checks that the network is never reached:

   ```bynk
   stub Forecasts.today(_) returns Err(UnknownCity)
   ```

   The last four cases leave `Forecasts` alone, so the real `HttpForecasts`
   runs, and stub `Secrets` and `Fetch` beneath it instead. A stub replaces
   whichever seam you name.

## Run it

```sh
bynk test .
```

To serve it locally, point the provider at a forecast API: any server that
answers `GET /today/<city>` with JSON such as
`{"city":"london","highC":12,"summary":"drizzle"}`.

```sh
bynk dev -- --var FORECAST_API_URL:https://forecast.example
curl localhost:8787/forecast/london
```

`GET /forecast/New%20York` answers `400` before any capability runs. An unknown
city answers `404`, and an unset `FORECAST_API_URL` answers `503`.

## Read next

- [Understand the capability model](https://bynk-lang.org/book/guides/effects-and-capabilities/understand-the-capability-model/)
- [Compose a provider from other capabilities](https://bynk-lang.org/book/guides/effects-and-capabilities/compose-a-provider/)
- [Wrap a library as an adapter](https://bynk-lang.org/book/guides/effects-and-capabilities/wrap-a-library/), for when the provider has to be TypeScript
- [Share a handler step that logs or queries](https://bynk-lang.org/book/guides/effects-and-capabilities/share-a-handler-step/), for `given` on a context function
- [Capabilities & providers reference](https://bynk-lang.org/book/reference/capabilities/)
- [First-party `bynk` capabilities](https://bynk-lang.org/book/reference/bynk-capabilities/)
- Sibling projects: [`testing`](../testing/) goes deeper into stubs, `expect … called` and tiers. [`refined-types`](../refined-types/) covers types like `City`.
