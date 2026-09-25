---
name: event_engine-info
description: Use to learn what event_engine offers — events, domains and subjects, process types, processors and handlers, and the schema catalog the rest of the gem reads from.
tools: Read
scope: events — registering processors and publishers, building the schema catalog, and directing emitted events to the right processor
---

This local explains event_engine and the vocabulary its world is built on. It
changes nothing and gives no steps — read it to orient, then go to the local that
owns the work.

## What event_engine is

event_engine is a Rails engine for applications that want events as a first-class
seam rather than a pile of callbacks. Each event is described by a schema — a
name, a version, the domain it belongs to, its subject, and the shape of its
payload. Those schemas are aggregated into one committed catalog that the app
loads at boot, and the catalog is authoritative: an event the catalog doesn't
know cannot be emitted. Emitting is therefore a checked operation, and the set of
events a system can produce is reviewable in a single file.

Reach for it when several parts of an app need to react to the same domain
occurrence, when you want the contract for those occurrences written down and
diffable, or when different classes of event need to travel different roads —
some handled in the request, some queued, some pushed to a broker, some recorded
for telemetry or sourcing. An emitted event is checked against the catalog,
routed to exactly one processor for that road, and then dispatched to any
handlers subscribed to its process type. Routing is opt-in: configure nothing and
events skip processing and go straight to handlers; configure any routing at all
and an event with no matching processor is an error rather than a silent drop.

## Interface

This local documents no commands — it is background only.

The `event_engine-install` local owns hooking the engine into a host app and
configuring it. The `event_engine-develop` local owns the working surface:
registering processors, publishers and handlers, pointing the engine at the
schema sources it should aggregate, choosing how events route, and the rake tasks
that build and render the catalog. Everything you would actually call or run
lives in one of those two.

## How to use it

One decision: are you wiring event_engine into an app for the first time, or
building with it?

- Standing the engine up in a host app, or changing how it is configured →
  `event_engine-install`.
- Adding events, registering processors or handlers, setting up routing,
  publishing a pack's schema, or rebuilding the catalog → `event_engine-develop`.

If you only needed the vocabulary, you have it — stop here.

## Conventions

- **Event** — one occurrence, identified by an `event_name` and an
  `event_version`. Carries a payload plus an envelope: metadata, the time it
  occurred, an idempotency key, and optional aggregate identity
  (`aggregate_type`, `aggregate_id`, `aggregate_version`).
- **Domain** — the bounded area an event belongs to. Event names are looked up
  within a domain, so the same name may exist in more than one.
- **Subject** — the thing an event is about, declared in its own registry with
  metadata. Subjects are named vocabulary shared across events, not per-event
  fields.
- **Process type** — how an event should travel: `inline`, `background`,
  `durable`, `broker`, `telemetry`, or `sourced`. It comes from the schema, not
  the call site.
- **Processor** — the single destination an event is routed to. Resolution is
  most-specific-first: a processor bound to the event name, then one bound to the
  domain, then the configured default.
- **Handler** — a subscriber that runs after processing. Handlers are registered
  against process types (or all of them), and every match runs. Many handlers per
  event; one processor.
- **Catalog** — the committed JSON file the app boots from, aggregated from each
  publishing pack's own `schema.json`. Packs own their schemas; the catalog is
  the assembled whole. If it is missing, development and test warn, other
  environments refuse to boot.
- **Publisher** — the seam a pack emits through, so a pack depends on a small
  publishing port rather than on the engine's internals.
- **Version** — omit one when emitting and the latest schema for that event wins;
  name one to pin.
