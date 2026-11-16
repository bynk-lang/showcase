# Review guidelines for the Bynk showcase

These are the maintainers' notes for reviewing a pull request here. The
showcase is a set of small Bynk projects, one per top-level directory. Each
shows one language feature, or a small group of closely related ones, written
the way Bynk is meant to be written. People new to Bynk read these to learn
what idiomatic code looks like, so a project is judged as teaching material as
well as code.

Skip what CI already enforces: `bynk fmt --check`, `bynk check` and
`bynk test` on every project at the pinned `BYNK_VERSION`, `bynk check` at
the workspace root, and a mutation score where a project has a
`.mutation-gate` file.

## What matters most

- **One idea per project.** A project shows the feature its README names,
  and little else. Flag a change that pulls in a second idea; that idea gets
  its own project.
- **Idiomatic Bynk.** Code is written the way the book teaches: refined types
  and validation at the boundary, `Result` and optionals rather than sentinel
  values, capabilities named in `given`, `match` where it reads better than a
  chain of conditions. Flag a workaround a reader might copy, and a pattern
  the book advises against, even when it compiles.
- **Correct as well as clear.** An example is copied into real code, so a
  security slip in one spreads. Watch for:
  - secrets or tokens in code, configuration or tests (use the platform's
    secrets, and stub them in tests);
  - untrusted input used before it's validated;
  - webhooks or tokens trusted without their signature being checked;
  - SQL built from strings rather than bound parameters.
- **The feature is tested.** `bynk test` exercises the feature the project is
  about, not just the code around it: its failure cases too, such as a
  refused input, a `Retry`, an expired session or a limit reached.
- **Experimental features are marked.** A project that uses an experimental
  module lists it under `[unstable] allow` in its `bynk.toml`, and its README
  says the feature is experimental.

## A project's README

Each project's README covers:

- **what the feature is**, through a small scenario a reader can follow;
- **why Bynk does it that way**;
- **what to read next** in [the book](https://bynk-lang.org/book/);
- **how to run it** (`bynk test .`, and `bynk dev` if it has an HTTP
  context).

The README is read alongside the code, so names, routes and outputs it quotes
must match the code. Flag a README that has drifted from what the code does.

## A new project

- A new top-level directory is a project, with its own `bynk.toml`, `src`,
  `tests` and README. The root is a workspace whose members are every
  top-level directory, so anything else at the top level breaks `bynk check`.
- It adds a row to the table in the root README: the project, what it shows,
  and the book page to read, linked.
- It doesn't overlap an existing project's idea; if it extends one, say how.

## The pinned version

`BYNK_VERSION` is moved by the org canary's pull request, once every project
passes at the new release. A hand-edited pin needs a reason in the pull
request. A change that needs a newer release than the pin should wait for
that pull request rather than bump the pin itself.

## Style

- British English throughout: in code comments, READMEs and strings
  ("behaviour", "authorisation", "colour"; "licence" as a noun).
- Comments explain why, in plain sentences, for a reader meeting the feature
  for the first time. Don't comment what the code already says.
- Names a newcomer would understand, from the project's scenario, over
  abstract ones (`order`, `packingJob`, not `x`, `data`).

## Severity here

- **Blocking:** a security slip a reader would copy, a project that teaches
  the wrong way to use a feature, a README that contradicts its code, or a
  change that breaks the workspace.
- **Should fix:** an untested feature or failure case, a second idea in one
  project, a missing README section or table row, or a pattern the book
  advises against.
- **Nit:** wording, naming and small style points. Keep these few.
