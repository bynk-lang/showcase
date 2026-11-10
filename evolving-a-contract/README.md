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

[`src/shop/payment.bynk`](src/shop/payment.bynk) is the callee. Its request
gained a field after callers were live, and it was added with a default:

```bynk
type Charge = {
	pence: Int,
	currency: String = "GBP",
}
```

The default is what makes this compatible. A caller compiled before `currency`
existed doesn't send it, and the callee fills in `"GBP"`. Added as a plain
required field, the same change would be breaking: the callee couldn't decode a
request from a live caller, so both would have to deploy together.

Its response gained a field too, and that one needs no default. When the callee
deploys first, the only skewed pair is an old caller and a new callee, and a
caller compiled before `method` existed ignores it:

```bynk
type Authorisation = {
	approved: Bool,
	method: String,
}
```

[`src/shop/orders.bynk`](src/shop/orders.bynk) is the caller. It leaves
`currency` out, so the default applies, and reads `method` like any other
field:

```bynk
let a <- Payment.authorise(Charge { pence: pence })
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

The order only goes one way. A caller can't deploy ahead of its live callee,
whatever the verdict: the callee refuses a contract hash it wasn't built to
accept. So the default is what lets *this* change go callee first, and
`shop.orders` follows once `shop.payment` is live.

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
