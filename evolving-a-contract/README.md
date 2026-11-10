# Evolving a contract

Two contexts that deploy as separate Workers, a payment service and the orders
service that calls it, and a change to the payment contract that can ship
before its caller does.

## The idea

When `shop.orders` calls `shop.payment`, the compiler checks the call against
`shop.payment`'s source as it is at that moment, and stamps a hash of that
contract into the caller. The callee carries the hash of its own contract and
compares the two before it reads a request. If they differ, it answers
`409 ContractMismatch` rather than decode a body whose meaning is in doubt.
`bynk deploy` makes the same comparison before anything ships, and refuses a
deploy that would put the two out of step.

So changing a contract is a deploy question. Which changes can the callee ship
first, while callers built against the old contract are still live? The
receiver must be able to decode whatever the sender can produce, so the answer
depends on the direction:

| Change | In a request | In a response |
|---|---|---|
| Optional field added | compatible | compatible |
| Field with a default added | compatible | compatible |
| Required field added | breaking | compatible |
| Field removed | compatible | breaking, unless it was an `Option` or had a default |
| Sum variant added | compatible | breaking |

(The book's table has the rest.) A compatible change can go callee first. A
breaking one needs both sides to move together, which a whole-project
`bynk deploy` does.

## Walkthrough

[`src/shop/payment.bynk`](src/shop/payment.bynk) is the callee. Its response
gained a field after callers were live, and it was added with a default:

```bynk
type Authorisation = {
	approved: Bool,
	method: String = "card",
}
```

A caller compiled before `method` existed ignores it. A caller compiled after
it, talking to a callee that doesn't send it yet, gets `"card"`. The handler
shows the other side of a default: a literal can leave the field out.

```bynk
on call(pence: Int) -> Effect[Authorisation] {
	Authorisation { approved: pence <= 10_000 }
}
```

[`src/shop/orders.bynk`](src/shop/orders.bynk) is the caller. It reads
`method` like any other field:

```bynk
let a <- Payment.authorise(pence)
if a.approved { "paid by \(a.method)" } else { "declined" }
```

[`tests/shop/payment.bynk`](tests/shop/payment.bynk) tests the callee in
process. [`tests/shop/checkout.bynk`](tests/shop/checkout.bynk) is a `system`
suite: each context runs as the Worker it deploys as, so the call crosses the
real wire, contract hash included. Below `system`, a case can't reach another
context's service at all (`bynk.tier.cross_context_needs_system`).

## Deploying the change

Deploying `shop.payment` on its own, while `shop.orders` was built against the
old contract, is refused by default (`bynk.deploy.contract_skew`). The refusal
says whether each difference is compatible or breaking. For a compatible one,
the callee can go first:

```sh
bynk deploy --context shop.payment --accept-compatible-skew
```

That records the older contract the live caller was built against in
`bynk.contracts.lock`, which you commit, and builds the callee to answer both
hashes. Deploy `shop.orders` when you're ready, then delete the entry. A
breaking change is never accepted this way.

## Run it

```sh
bynk test .
```

## Read next

- [Contract skew across independently deployed contexts](https://bynk-lang.org/book/guides/projects-build-and-deployment/contract-skew/)
- [Consume another context's services](https://bynk-lang.org/book/guides/program-structure/consume-services/)
- [System tests](https://bynk-lang.org/book/reference/testing/#system-tests)
- [Wire format](https://bynk-lang.org/book/reference/wire-format/)
- Showcase: [`events`](../events/) for contexts that talk by events instead
  of calls.
