---
name: event_engine-store-info
description: Use to learn what event_engine-store offers — the permanent append-only record of every dispatched event, replay of that record in order, and projections kept live and rebuilt from it.
tools: Read
scope: event store — recording every dispatched event to an append-only table, replaying the log in order, and rebuilding projections from it
---

This local explains event_engine-store and the vocabulary it uses. It changes
nothing and gives no steps — read it to orient, then go to the local that owns the
work.

## What event_engine-store is

event_engine-store is a Rails engine that adds a permanent record to an app built
on event_engine. Once installed, every event event_engine dispatches is written as
one row to a table the host app owns, whatever its process type. Rows are never
updated: the table is the history of what happened, in the order it happened.

Reach for it when an app needs to answer "what happened, and when" from a durable
log, rebuild a read model (counters, dashboards, search indexes) from history, or
backfill a new read model from events recorded before it existed. It does not
aggregate or compute metrics, and it does not deliver events anywhere — it records
them and reads them back.

## Interface

This local documents no commands — it is background only.

The `event_engine-store-install` local owns adding the gem to a host app and
creating its table. The `event_engine-store-develop` local owns everything an app
does with the record: querying it, replaying it, registering and rebuilding
projections, and changing what gets recorded.

## How to use it

One decision: is the store already in the app?

- Adding the gem to an app for the first time, or the table is missing →
  `event_engine-store-install`.
- Querying the log, replaying it, writing a projection, or changing what is
  recorded → `event_engine-store-develop`.

If you only needed the vocabulary, you have it — stop here.

## Conventions

- **Stored event** — one row in the log, holding one dispatched event's name,
  type, version, process type, payload, metadata, occurred-at time, idempotency
  key, and aggregate type / id / version. The event's subject and domain are not
  stored.
- **Append-only** — a row is written once and never changed. Order is the row's
  insertion order.
- **Recording** — happens automatically for every dispatched event, inside the
  emit call, with no configuration.
- **Replay** — reading the log back from the first row to the last, as event
  objects.
- **Projection** — an object with an `apply(event)` method that builds a read
  model from events. A registered projection receives each event as it is
  dispatched; any projection can be rebuilt by replaying the whole log into it.
- **Companion gems** — event_engine (required) defines and dispatches events.
  event_engine-delivery keeps a temporary outbox for delivery; the two can run
  side by side.
