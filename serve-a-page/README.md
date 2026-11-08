# Serve a page

A page built from string literals gets hard to read fast: markup, escaping and
logic share one line. This project keeps the markup in a real `.html` file, reads
it into a `String` with an `embed`, fills in the gaps, and serves the result from
an HTTP route as a `Raw` response with an HTML content type.

## The idea

An `embed` hands you a file's text and nothing more. The `{{ }}` markers in the
page are only a convention of that file; the language gives them no meaning. Your
code replaces each one, and escapes any text it inserts, because the embed will
not. The stylesheet is an `asset`, so the page links a content-hashed URL.

## Walkthrough

**`embeds/page.html`** is the shell, with a marker wherever something changes:

```html
<title>{{title}}</title>
<link rel="stylesheet" href="{{style}}">
...
{{content}}
```

**`src/app/page.bynk`** declares the embed and asset, and fills the shell:

```bynk
asset style = "assets/page.css"

embed shell = "embeds/page.html"

fn render(title: String, content: String) -> String {
	shell
		.replace("{{style}}", style.url)
		.replace("{{title}}", escape(title))
		.replace("{{content}}", content)
}
```

`title` is escaped here. `content` is markup the caller built, so the caller
escaped the text inside it.

**`src/app/web.bynk`** serves it. `Raw` writes the bytes straight into the
response and the handler chooses the content type:

```bynk
on GET("/") () -> Effect[HttpResult[()]] by Visitor {
	Raw(Bytes.fromUtf8(render("Home", "<p>Hello</p>")), "text/html; charset=utf-8")
}
```

**`tests/app/web.bynk`** can name the embed, so it checks that the shell has its
placeholders, that `render` fills every one, that a title is escaped, and that
`GET /` answers with a `Raw` result:

```bynk
case "the page fills every placeholder" {
	let page = render("Home", "<p>Hello</p>")
	expect page.contains("<title>Home</title>")
	expect page.contains("{{") == false
}
```

## Run it

```sh
bynk test .
bynk dev        # then open http://localhost:8787/
```

## Read next

- [Serve a page from an HTML file](https://bynk-lang.org/book/guides/entry-points/serve-a-page/)
- [Embedded text](https://bynk-lang.org/book/reference/embeds/)
- [Static assets](https://bynk-lang.org/book/reference/assets/)
- Sibling project: [verify-webhooks](../verify-webhooks/) for another HTTP entry point.
