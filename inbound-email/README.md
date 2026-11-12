# Inbound email

A support desk's mailbox. A service bound to an address receives each message
and returns a verdict (accept, reject, forward or reply), and the runtime
carries it out. Inbound email is **experimental** in Bynk.

## The idea

`service support from email("support@shop.example")` claims an address. Its one
handler, `on message(mail: InboundEmail) -> Effect[EmailVerdict]`, decides what
becomes of each message and calls no mail API:

| Verdict | What happens |
|---|---|
| `Accept` | Nothing more. |
| `Reject(reason)` | A permanent SMTP rejection. |
| `Forward(to)` | Passed to one verified address in the account. |
| `Reply(message)` | An answer to the sender. The runtime fills in `From`, `To` and the threading headers, so a reply can only go back to the sender. |

Keeping the handler a pure decision is what makes it testable: a case builds an
`InboundEmail`, calls the handler, and checks the verdict.

**Don't trust `from`.** `mail.from` is the envelope sender (SMTP `MAIL FROM`),
and anyone can write any address there. The handler runs as the `Sender` actor,
whose identity carries Cloudflare's DMARC verdict (`DmarcPass`, `DmarcFail` or
`DmarcNone`). DMARC vouches for the domain in the message's `From` header, not
for `mail.from`, so a pass says the message is genuinely from that domain, not
that the envelope sender is. Decide on the evidence, never on the claim. A
`Reply` goes back through Cloudflare, which allows one reply per message and
only to a sender whose mail passed DMARC.

**Don't answer robots.** An auto-reply must not answer another auto-reply, an
out-of-office, a bounce or list mail (RFC 3834), or two helpdesks can thank each
other forever. The runtime doesn't check for this, so `triage` does, through
`isAutomated`: an `Auto-Submitted` header other than `no`, a `Precedence` of
`bulk`, `list` or `junk`, or a `List-Id`.

## Walkthrough

[`src/helpdesk/inbox.bynk`](src/helpdesk/inbox.bynk) puts the decision in a
pure function, so every branch can be tested:

```bynk
fn triage(mail: InboundEmail, verified: Bool) -> EmailVerdict {
	if mail.size > MaxSize {
		Reject("message too large")
	} else if mail.subject.toLower().contains("refund") {
		Forward("billing@shop.example")
	} else if verified && !isAutomated(mail) {
		Reply(EmailReply { text: Some("Thanks, we have your message and will be in touch.") })
	} else {
		Accept
	}
}
```

The service works out `verified` from the `Sender` it runs as:

```bynk
service support from email("support@shop.example") {
	on message(mail: InboundEmail) -> Effect[EmailVerdict] by s: Sender {
		triage(mail, s.identity.dmarc == DmarcPass)
	}
}
```

A second service, `from email("*@shop.example")`, catches every other address
on the domain and refuses it. A named address always beats the catch-all.

[`tests/helpdesk/inbox.bynk`](tests/helpdesk/inbox.bynk) builds messages with
only the fields each case is about; the rest have defaults. `support.message(…)`
runs the handler with no Worker and no mail. A suite has no Email Routing, so the
sender's verdict there is always `DmarcNone`, and the reply branch is tested
through `triage` with `verified` true and false. Two more cases pin a refund
spotted whatever its case, and an out-of-office or bulk digest left unanswered
even when verified.

## Run it

```sh
bynk test .
```

To deploy, turn on Email Routing for the domain and verify any address you
forward to. `bynk deploy` lists the claimed addresses in the Worker's
`wrangler.toml`, and the build's `package.json` names `postal-mime`, which
parses each message: run `npm install` in the build directory first. Locally,
`bynk dev` accepts a raw message:

```sh
curl -X POST 'http://localhost:8787/cdn-cgi/local/email?from=a@example.org&to=support@shop.example' \
  --data-binary @message.eml
```

## Read next

- [Receive email](https://bynk-lang.org/book/guides/entry-points/receive-email/)
- [Inbound email reference](https://bynk-lang.org/book/reference/inbound-email/):
  limits, faults and routing
- Showcase: [`queues`](../queues/) for the other entry point that returns a
  verdict (`Ack` or `Retry`), and [`verify-webhooks`](../verify-webhooks/) for
  checking that a sender is who it claims.
