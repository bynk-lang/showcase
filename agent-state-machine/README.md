# Agent state machine

A help-desk ticket as a Bynk agent. Each ticket id addresses its own instance,
which keeps its state in `Cell`s. The ticket's status is a state machine:
`Open → InProgress → Resolved → Closed`, with `Resolved → InProgress` when a
ticket is reopened. Invariants state what must hold of every committed state,
and the runtime enforces them. A tiny HTTP service exposes the ticket.

## The idea

An agent is Bynk's unit of state: a `key`, some `store` fields, and handlers.
On Cloudflare each key becomes its own Durable Object, so two tickets never
share state, and a handler's writes commit together when it returns, or not at
all if it faults.

Modelling the state as a sum buys you three things. The initialiser names the
start state, so a never-seen key is `Open` rather than "uninitialised". A
transition is just an assignment (`status := Resolved`). Reading the state is
an exhaustive `match`, so a handler can't forget a state.

Bynk keeps two kinds of "no" apart. A move from the wrong state, such as
closing an open ticket, is an outcome the caller can act on, so it's a value:
`Err(WrongState(current))`, which the service turns into `409 Conflict`. An
**invariant** is a contract instead: a claim about every reachable state,
checked at each commit. Breaking one is a fault, the offending state is never
written, and the caller sees a 500.

## Walkthrough

1. [`src/helpdesk/desk.bynk`](src/helpdesk/desk.bynk): the types, the agent and
   the service. The state machine is one sum-typed `Cell`, and the rest is
   extended state that rides along:

   ```bynk
   store status: Cell[Status] = Open
   store assignee: Cell[Option[Engineer]]
   store reopens: Cell[Int]
   ```

   Each handler matches on the current state, moves only from the state it
   expects, and returns every other state as a rejection:

   ```bynk
   on call close() -> Effect[Result[Status, Rejection]] {
   	match status {
   		Resolved => {
   			status := Closed
   			Ok(Closed)
   		},
   		current => Err(WrongState(current)),
   	}
   }
   ```

   Between the stores and the handlers sit the contracts. An `invariant`
   judges one committed state, and a `transition` judges the step from the
   last committed state (`old`) to the new one (`new`):

   ```bynk
   invariant reopen_cap:
   	reopens <= 2

   transition closed_is_final:
   	old.status is Closed implies new.status is Closed
   ```

   No handler checks the reopen cap, so `reopen_cap` is the only guard. The
   handlers already respect `closed_is_final`, so it documents the rule and
   would catch a future handler that broke it.

2. [`tests/helpdesk/desk.bynk`](tests/helpdesk/desk.bynk): the suite drives
   the agent by key. It covers a fresh ticket, the happy path, refused moves
   (and that they change nothing), keys staying independent, and the HTTP
   `409`. The invariant case reopens a ticket a third time, claims the fault,
   then reads the ticket back to show the bad state was never written:

   ```bynk
   expect t.reopen() faults
   let v <- t.view()
   expect v.status == Resolved
   expect v.reopens == 2
   ```

## Run it

```sh
bynk test .
bynk dev        # serves the ticket API on http://localhost:8787
```

## Read next

- [The agent model](https://bynk-lang.org/book/guides/agents-and-state/the-agent-model/)
- [Build a stateful agent](https://bynk-lang.org/book/guides/agents-and-state/stateful-agent/)
- [Model an agent as a state machine](https://bynk-lang.org/book/guides/agents-and-state/state-machine/)
- [Invariants as contracts, tests as behaviour](https://bynk-lang.org/book/guides/agents-and-state/understand-invariants/)
- Reference: [Agents](https://bynk-lang.org/book/reference/agents/) and
  [Agent invariants](https://bynk-lang.org/book/reference/agent-invariants/)
- Showcase: [`storage-and-queries`](../storage-and-queries/) for the other
  storage kinds, and [`testing`](../testing/) for more on suites and doubles.
