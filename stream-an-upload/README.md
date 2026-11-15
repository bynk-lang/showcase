# Stream an upload

Accept a video too big to hold in memory and pass it straight on to R2, a chunk
at a time, with a cap on how much a client may send.

## The idea

A `@raw` handler whose `body` is a `Stream[Bytes]` is handed the request body
as it arrives, instead of after it has been read whole. The type is the switch:
`body: Bytes` buffers, `body: Stream[Bytes]` streams.

A `@raw` route must bound its body, with a `@limit(maxBody: …)` on the handler
or a `limits { maxBody: … }` on the service. A streamed body is counted as it's
read, so the cap holds even when a client sends no length: a body that crosses
it stops the read, and the router answers `413`.

A stream is read once. Handing it to R2 consumes it, and it can't be passed to
an agent or another service. Store where it went, not the bytes.

## Walkthrough

[`src/media/videos.bynk`](src/media/videos.bynk) has one route:

```bynk
@raw(contentType: "video/mp4")
on PUT("/videos/:name") (
	name: String,
	headers: RequestHeaders,
	body: Stream[Bytes]
) -> Effect[HttpResult[()]] by Visitor given Videos {
	let Some(length) = headers.get("content-length") else {
		BadRequest("send a Content-Length")
	}
	let Some(size) = Int.parse(length) else { BadRequest("Content-Length is not a number") }
	let _ <- Videos.putStream(name, body, size)
	NoContent
}
```

`putStream` writes exactly `size` bytes. A stream with more or fewer faults the
write, and R2 stores nothing, so a client that lies about its length can't
leave half a video behind. A browser that `PUT`s a `File` sends a length. An
upload sent chunked has none, so the handler refuses it.

[`tests/media/videos.bynk`](tests/media/videos.bynk) is the unit suite. A case
passes the body as `Stream.of([…])` and sets `Content-Length` itself, then
reads the in-memory bucket to see the chunks stored as one object.

[`tests/media/boundary.bynk`](tests/media/boundary.bynk) is a `system` suite,
where the router's checks run: a `text/plain` body is refused before the
handler, and a chunked stream reaches the handler with no length.

## Run it

```sh
bynk test .
bynk dev
```

Then, from another terminal:

```sh
curl -i -X PUT -H "Content-Type: video/mp4" --data-binary @clip.mp4 \
  http://localhost:8787/videos/clip.mp4
```

## Read next

- [Stream a large upload](https://bynk-lang.org/book/guides/entry-points/stream-a-large-upload/)
- [Reference: streamed request bodies](https://bynk-lang.org/book/reference/http/#streamed-request-bodies)
- [Testing: sending a streamed body](https://bynk-lang.org/book/reference/testing/#sending-a-streamed-body)
- Showcase: [`files-in-r2`](../files-in-r2/) for small files held in memory, and
  [`forms`](../forms/) for a browser's multipart upload.
