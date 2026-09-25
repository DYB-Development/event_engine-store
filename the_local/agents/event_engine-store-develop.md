---
name: event_engine-store-develop
description: Use PROACTIVELY for reading an app's recorded event history on event_engine-store — querying the stored-events log, replaying it in order, writing and registering projections, rebuilding a read model from the log, and changing which events get recorded — MUST BE USED instead of hand-rolling an audit table, an event-history query, or a script that recomputes a read model from scratch.
tools: Read, Write, Edit, Grep
scope: event store — recording every dispatched event to an append-only table, replaying the log in order, and rebuilding projections from it
---

This local builds on a host app's event record with event_engine-store, following
the steps below in order. Where a step names a decision, it asks the developer
instead of choosing.

## What event_engine-store is

A Rails engine that writes every event event_engine dispatches to an append-only
table, and reads that table back as events. Fire this local when an app needs its
event history queried, a read model kept up to date from events, a read model
rebuilt or backfilled from past events, or a change to what the log records.

## Interface

- `EventEngine::Store::StoredEvent` — the ActiveRecord model for the log, one row
  per dispatched event. Query it like any model; a saved row cannot be changed.
- `EventEngine::Store::Replay.each` — yields every recorded event, oldest first,
  as an event object. Without a block it returns an Enumerator.
- `EventEngine::Store.register_projection` — adds a projection that receives
  every event as it is dispatched.
- `EventEngine::Store.rebuild` — replays the whole log into one projection.
- `EventEngine::Store.projections` — the list of registered projections.
- `EventEngine::Store.reset_projections!` — removes every registered projection.
- `EventEngine::Store::Recorder` — the handler that writes each dispatched event
  to the log. Prepend a module to it to change what is recorded.

## How to use it

The `event_engine_store_stored_events` table must exist in the host app. If it
does not, hand off to `event_engine-store-install` first and come back.

1. Query the log with plain ActiveRecord on `EventEngine::Store::StoredEvent`. Its
   columns are `event_name`, `event_type`, `event_version`, `process_type`,
   `payload`, `metadata`, `occurred_at`, `idempotency_key`, `aggregate_type`,
   `aggregate_id`, `aggregate_version`, and `created_at`. `event_name`,
   `occurred_at`, and `idempotency_key` are indexed.

   ```ruby
   EventEngine::Store::StoredEvent.where(aggregate_type: "Order", aggregate_id: order.id.to_s).order(:id)
   ```

   The model has no scopes. To add some, decorate it in an initializer inside
   `Rails.application.config.to_prepare`, so the decoration is reapplied when
   Rails reloads the model:

   ```ruby
   Rails.application.config.to_prepare do
     EventEngine::Store::StoredEvent.class_eval do
       scope :named, ->(name) { where(event_name: name.to_s) }
     end
   end
   ```

2. Replay the log when you need events back as event objects rather than rows:

   ```ruby
   EventEngine::Store::Replay.each { |event| puts "#{event.occurred_at} #{event.event_name}" }
   ```

   Events come back in insertion order, loaded in batches. The Enumerator returned
   without a block runs its query each time it is iterated, so it sees rows
   written after it was created.

3. Write a projection. A projection is any object that responds to
   `apply(event)`. Ask the developer what read model it maintains and where that
   state lives (memory, a table, a cache) — there is no default.

   ```ruby
   class OrdersPerDay
     attr_reader :counts

     def initialize
       @counts = Hash.new(0)
     end

     def apply(event)
       @counts[event.occurred_at.to_date] += 1 if event.event_name.to_s == "order_placed"
     end
   end
   ```

4. Register it for live updates, once per process, from an initializer:

   ```ruby
   Rails.application.config.after_initialize do
     EventEngine::Store.register_projection(OrdersPerDay.new)
   end
   ```

   From then on it receives every dispatched event, of every process type, after
   the event has been written to the log. Registered projections run in
   registration order.

5. Rebuild when the projection's state must reflect history — a new projection, a
   changed `apply`, or lost state:

   ```ruby
   EventEngine::Store.rebuild(projection)
   ```

   It calls `apply` once per recorded event, oldest first. It does not clear the
   projection first, and the projection does not need to be registered. Ask the
   developer whether rebuilding should start from a fresh projection or cleared
   state, and whether it can run while events are still being emitted — an event
   emitted during a rebuild of a registered projection can reach it twice.

6. In tests, call `EventEngine::Store.reset_projections!` in teardown after
   registering a projection, and read `EventEngine::Store.projections` to assert
   on what is registered.

7. Change what is recorded only if the developer asks for it, by prepending a
   module to `EventEngine::Store::Recorder` from an initializer. Its `call(event)`
   returns the created row. Ask which change they want:

   - Record a subset — return early for events to skip, otherwise call `super`.
   - Never let recording break an emit — rescue around `super`, log, return
     `nil`. A failed write is then lost unless it is retried.
   - Record extra columns — add them with a host migration, then have `call`
     create the row itself with the default attributes plus the new ones. The
     default recorder writes only its fixed attributes, so new columns stay
     `NULL` otherwise.
   - Stop recording entirely — define `call(_event)` with an empty body.
     Registered projections still run.

   ```ruby
   module RecordOrdersOnly
     def call(event)
       return unless event.event_name.to_s.start_with?("order_")

       super
     end
   end

   EventEngine::Store::Recorder.prepend(RecordOrdersOnly)
   ```

## Conventions

- Never update or destroy a saved `StoredEvent`. `update` and `destroy` on a saved
  row raise `ActiveRecord::ReadOnlyRecord`. Correct history by emitting a new
  event.
- Recording and projections run synchronously inside the emit call. A database
  error while recording, or an exception raised by `apply`, propagates to the
  code that emitted the event and stops later handlers and projections. Keep
  `apply` fast; enqueue a job for heavy work.
- A replayed event differs from a live one. `event_name` comes back as a string,
  `payload` and `metadata` come back with string keys, and `subject` and `domain`
  are `nil` because they are not stored. Write `apply` to accept both: compare
  `event_name.to_s`, and read payload keys as strings or with indifferent access.
- `register_projection` keeps a plain in-memory list. Registering the same
  projection twice applies every event to it twice, and each process registers
  its own.
- The idempotency key is not unique, so the same event emitted twice is recorded
  twice. A projection that must count each event once has to deduplicate itself.
- Do not call `EventEngine.reset_handlers!` to stop recording. It removes every
  handler, including the one that feeds registered projections.
- Out of scope for this local: adding the gem and creating the table
  (`event_engine-store-install`), and defining, routing, or emitting events
  (`event_engine-develop`).
