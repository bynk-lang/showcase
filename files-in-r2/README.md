# Files in R2

A small file vault: upload a file, download it, list a folder. It shows the `R2`
capability, which keeps objects in a Cloudflare R2 bucket, and its write-once
condition.

## The idea

A bucket is a named instance of `R2`. You declare it once, ask for it with
`given`, and call its operations: `get`, `put`, `head`, `list` and more. Objects
move as `Bytes`. An object store is also where you want to refuse an overwrite,
so `putWith` takes a condition: `Absent` creates only, and answers `None`,
writing nothing, when the key is taken.

`R2` is experimental, so the project opts in in [`bynk.toml`](bynk.toml):

```toml
[unstable]
allow = ["bynk.cloudflare.R2"]
```

## Walkthrough

[`src/vault/files.bynk`](src/vault/files.bynk) is one context. It consumes the
adapter twice, once for the capability and once for the types its operations
use, then names the bucket. A bare `given R2` is refused, so every bucket has a
name:

```bynk
consumes bynk.cloudflare
consumes bynk.cloudflare { R2 }

capability Archives = R2
```

`bynk deploy` creates the bucket as `<worker>-archives`. The upload writes with
`Absent`, so the second upload to a key is a `Conflict` and the first file
stays:

```bynk
let stored <- Archives.putWith(key, body, R2Put {
	contentType: Some("application/octet-stream"),
	metadata: Map.empty(),
	onlyIf: Absent,
})
match stored {
	Some(o) => Created(o.size)
	None => Conflict("that file already exists")
}
```

The download is a `get`, which gives `None` for a missing key. `Raw` sends the
bytes with a content type:

```bynk
let found <- Archives.get(key)
match found {
	Some(body) => Raw(body, "application/octet-stream")
	None => NotFound
}
```

`list(prefix, cursor)` returns one page of objects in key order. This vault
reads only the first page; pass a page's `cursor` back to read the next.

[`tests/vault/files.bynk`](tests/vault/files.bynk) needs no stub. Every case
gets its own in-memory bucket with the real conditions and paging. The cases
check that a file reads back byte for byte, that a second upload is refused and
leaves the first, and that a prefix lists only its keys. A case holds the same
`Archives` the handlers use, so it can call `Archives.head` to check the stored
size.

## Run it

```sh
bynk test .
bynk dev
```

With `bynk dev` running, `PUT /files/:key` stores the request body,
`GET /files/:key` returns it, and `GET /folders/:prefix` lists keys.

## Read next

- [Store files in R2](https://bynk-lang.org/book/guides/effects-and-capabilities/store-files-in-r2/):
  streaming, multipart uploads and compare-and-swap.
- [Capabilities reference](https://bynk-lang.org/book/reference/bynk-capabilities/#object-storage-r2):
  every operation.
