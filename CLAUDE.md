<!-- the_local:begin -->
## Delegate to your locals

This project has installed expert subagents. Before doing work yourself,
check whether a local owns it and delegate — never work from memory on
something a local covers:

- the_local-* agents

See each agent's description for specifics.
<!-- the_local:end -->

<!-- the_local:process:begin -->
Read and follow this develop process for all work in this project. It is
also written verbatim to `develop_process_rules.md` — reference that file directly.

# Develop Process

The standard process for writing code across all projects. Default to these rules
unless a project explicitly overrides them.

---

## Diverging from this process

Read this process before starting work and follow it — it is the default for
every session. If a task genuinely calls for breaking one of these rules, do not
silently deviate: **PAUSE and ask for a one-time exception**, naming the rule and
why it should be set aside here. An exception is granted for that instance only —
it needs no doc or notes update — and then you continue. Do not treat a granted
exception as a standing change to the process.

---

## Test-Driven Development

TDD is the default for everything. Work one tiny cycle at a time:

1. **Write one test that asserts one thing.**
2. **Run it and watch it fail** — for the right reason. A test you never saw fail
   proves nothing.
3. **Write the minimum code to make it pass.**
4. **Run the test and watch it pass.**
5. **Commit.**
6. Repeat with the next test.

One assertion per test. One test per commit cycle. No batching multiple behaviors
into a single test or a single commit.

---

## Commits

- A commit is normally **two files: the test file and the code file.**
- When implementing or updating an interface (e.g. a new controller endpoint) a
  commit may touch more files (route + controller + view) — that is the minimal
  coherent unit for that interface, and it is allowed.
- Keep each commit focused on the one behavior the test describes.

---

## What to Test

- **Test our own code only.**
- **Never test third-party code** — not a gem, not an API, not a framework. The
  only test that may reference a dependency is one that asserts *our system is
  correctly wired to it* (the integration seam), never the dependency's own
  behavior.
- **Never test another interface inside a unit test.** A test covers one interface.
  The single exception is the smoke integration test described below.

---

## Smoke Integration Test

When implementing an interface, write **one smoke integration test** that exercises
the interface end to end and proves the pieces are connected. This is the one place
where touching more than the unit under test is expected and correct.

---

## Pull Requests

- **Always work on a feature branch and open a PR.** Confirm the target branch
  before any git operation (`git branch --show-current`).
- **Keep PRs small and manageable** — typically **no more than 8–10 files.**
- Keep the focus of a PR narrow. One concern per PR.
- **All tests pass before opening the PR.**
- **The linter and every other CI check pass before opening the PR.**
- Never start a new PR until the previous one is merged.

---

## Code Quality

- Follow Clean Code principles: small functions, clear names, no surprises.
- Follow SOLID principles. Readable by a human first.
- Keep it simple — no abstraction until a real need calls for it.
- Explicitly require libraries rather than assuming autoload.

## Comments

- **Write self-documenting code, not comments.** Code should be clean and readable
  on its own. Names — of classes, methods, variables, and partials — carry the intent.
- **A comment is a smell.** If you feel a comment is needed, the code is either built
  wrong or needs refactoring (a clearer name, a smaller method, an extracted object or
  partial) so the intent is obvious without prose. Follow SOLID and this resolves itself.
- Do not leave explanatory headers on classes/methods, inline "what this does" notes,
  or section banners. Delete them and let the structure speak.
- Narrow exceptions, kept rare: a genuinely non-obvious *why* (a workaround for an
  external bug, a legal/security constraint) and machine-readable annotations the
  tooling requires (e.g. `rubocop:disable`). Prefer refactoring over a "why" comment
  whenever you can.
<!-- the_local:process:end -->










