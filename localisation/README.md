# Localisation

A tiny basket service that answers in the caller's language. The text lives in
a message bundle with English, French and Polish blocks. Counts go through ICU
plural rules, and the handler gets its language from the `Locale` capability,
which negotiates `Accept-Language` and falls back to English.

## The idea

With a bundle, a handler holds no user-facing text. It builds a **message**: a
stable code plus typed values. A **`messages` bundle** in a `commons` turns that
into text, one block per locale. The compiler checks the bundle as a set:
exactly one `@reference` block, every other locale declaring every code, and the
same placeholders and ICU format kinds everywhere. So adding a language means
adding a block, and a missing translation is a compile error, not a blank
screen.

Plurals are a runtime fact of each language. English says "0 items", French
says "0 article", and Polish has separate forms for 2 and 5. A
template only names the arms (`one`, `few`, `other`, and so on), and the host's own `Intl` plural
rules pick one. Bynk carries no CLDR data of its own.

The language comes from `Locale`, a first-party capability. On Cloudflare it
negotiates the request's `Accept-Language` against the locales the bundle
declares, so the handler holds no parsing code at all.

## Walkthrough

1. **`src/shop/messages.bynk`** is the bundle. The reference block sets the
   codes and placeholders every other block must match:

   ```bynk
   messages "en" @reference {
   	"basket.summary" => "{n, plural, one {# item} other {# items}} in your basket"
   }
   ```

   Polish adds the `few` and `many` arms its grammar needs. `basketSummary`
   wraps `render` in the same commons. Both `bynk.locale` and the bundle export a `render`, so
   keeping the call here means a context never `uses` both. Its count is an
   `ItemCount`, a refined `Int` declared in the same commons, so a negative count
   can't reach a plural template:

   ```bynk
   fn basketSummary(tag: LocaleTag, count: ItemCount) -> String {
   	render(tag, withWhole(message("basket.summary"), "n", count))
   }
   ```

2. **`src/shop/web.bynk`** is the HTTP context. It consumes `Locale` and asks
   it for a tag:

   ```bynk
   let tag <- Locale.current()
   Ok(basketSummary(tag, query.items))
   ```

   The route declares no `headers` parameter. A `system` test can still send
   an `Accept-Language` header, and `Locale` reads it from the request on its
   own.

3. **`tests/shop/messages.bynk`** tests the bundle with literal tags: the plural
   edges at 0, 1 and many in each language, and an undeclared `"de"` falling
   back to English. Note that `render` matches a tag exactly, so `"fr-CA"` also
   falls back. Truncating a regional tag is negotiation's job.

4. **`tests/shop/web.bynk`** runs at the unit tier, where `Locale` is a test
   double, and picks the language with a stub:

   ```bynk
   stub Locale.current() returns "pl"
   ```

5. **`tests/shop/negotiation.bynk`** is a `system` suite. There the real Worker
   builds its own `Locale` provider, so these cases drive the negotiation:
   `fr-CA` truncates to `fr`, quality values pick `pl`, and `de-DE, ja` or no
   header at all falls back to English.

## Run it

```sh
bynkc test .
bynk dev
curl -H "Accept-Language: fr-CA" "localhost:8787/basket?items=0"
# "0 article dans votre panier"
```

## Read next

- [Localisation](https://bynk-lang.org/book/guides/localisation/), the guide's overview
- [Understand localisation](https://bynk-lang.org/book/guides/localisation/understand-localisation/)
- [Declare a message bundle](https://bynk-lang.org/book/guides/localisation/declare-a-message-bundle/)
- [Format with ICU](https://bynk-lang.org/book/guides/localisation/format-with-icu/)
- [First-party `bynk` capabilities](https://bynk-lang.org/book/reference/bynk-capabilities/), for `Locale`
- [Request headers](https://bynk-lang.org/book/reference/http/) and [testing reference](https://bynk-lang.org/book/reference/testing/)
- Sibling projects: [`capabilities-and-providers`](../capabilities-and-providers/) covers the capability model, and [`testing`](../testing/) covers stubs and tiers.
