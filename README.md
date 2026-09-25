# EventEngine::Store

The permanent, queryable **event record** for
[EventEngine](https://github.com/DYB-Development/event_engine).

Where [`event_engine-delivery`](https://github.com/DYB-Development/event_engine-delivery)'s
outbox is a *transient delivery buffer* (rows are deleted once published and the
retention window passes), `event_engine-store` is the **durable source of truth**: an
immutable, append-only event log the host application owns. It registers a handler
with EventEngine that records **every dispatched event**, and provides
**event-sourcing replay** — rebuilding state by reading the log back in append order.

It deliberately does **not** aggregate or compute metrics — turning the log into
rollups is a separate concern.

| Gem | Keeps events…? |
|---|---|
| `event_engine-delivery` (outbox) | only until delivered + retention expires — a buffer |
| `event_engine-store` (this gem) | **forever, append-only** — the record |

The two are complementary; you can run both at once.

---

## Table of contents

- [Installation](#installation)
- [How it hooks into the core](#how-it-hooks-into-the-core)
- [The `StoredEvent` table](#the-storedevent-table)
- [Querying the log](#querying-the-log)
- [Customizing the store](#customizing-the-store) ← **start here for extensions**
  - [Expanding the table with your own columns](#expanding-the-table-with-your-own-columns)
  - [Adding query scopes to the model](#adding-query-scopes-to-the-model)
  - [Recording only some events](#recording-only-some-events)
  - [Replacing the recorder entirely](#replacing-the-recorder-entirely)
  - [Disabling the default recorder](#disabling-the-default-recorder)
  - [Making recording resilient / async](#making-recording-resilient--async)
- [Replay](#replay)
- [Projections](#projections)
- [License](#license)

---

## Installation

```ruby
# Gemfile
gem "event_engine"
gem "event_engine-store"
```

```bash
bundle install
```

Copy the migration into your app and run it:

```bash
bin/rails railties:install:migrations   # copies the StoredEvent migration
bin/rails db:migrate
```

There is **no install generator, initializer, or configuration** — the store wires
itself up at boot. Once migrated, every dispatched event is recorded automatically.

---

## How it hooks into the core

At Rails boot the engine registers **two** handlers with the core, for every process type:

```ruby
# lib/event_engine/store/engine.rb
initializer "event_engine.store.register_recorder" do
  config.after_initialize do
    EventEngine.register_handler(Recorder.new, process_types: :all)
    EventEngine.register_handler(ProjectionDispatcher.new, process_types: :all)
  end
end
```

So on every `EventEngine.<event>` call:

1. `Recorder#call(event)` inserts a `StoredEvent` row.
2. `ProjectionDispatcher#call(event)` calls `apply(event)` on each registered
   projection.

> Because both register at `process_types: :all`, the store records events of
> **every** process type, whichever processor `config/event_rules.yml` routes them to.
> That's by design: the store is your record of what happened, independent of how it
> was processed. If you only want to record some
> events, see [Recording only some events](#recording-only-some-events).

---

## The `StoredEvent` table

`EventEngine::Store::StoredEvent` (table `event_engine_store_stored_events`) is
**append-only**: once a row is persisted it is read-only (`readonly?` returns true on
persisted records), so an attempt to update raises `ActiveRecord::ReadOnlyRecord`.

| Column | Type | Indexed | Notes |
|---|---|---|---|
| `event_name` | string | ✓ | NOT NULL |
| `event_type` | string | | classification |
| `event_version` | integer | | schema version |
| `process_type` | string | | processor the event was routed to |
| `payload` | json | | event data |
| `metadata` | json | | context (actor, request id, …) |
| `occurred_at` | datetime | ✓ | logical event time |
| `idempotency_key` | string | ✓ | **not unique** — duplicates allowed |
| `aggregate_type` | string | | aggregate tracking |
| `aggregate_id` | string | | |
| `aggregate_version` | integer | | |
| `created_at` | datetime | | DB insert time (NOT NULL) |

The full event envelope is captured. The default migration:

```ruby
create_table :event_engine_store_stored_events do |t|
  t.string   :event_name, null: false
  t.string   :event_type
  t.integer  :event_version
  t.string   :process_type
  t.json     :payload
  t.json     :metadata
  t.datetime :occurred_at
  t.string   :idempotency_key
  t.string   :aggregate_type
  t.string   :aggregate_id
  t.integer  :aggregate_version
  t.datetime :created_at, null: false
end

add_index :event_engine_store_stored_events, :event_name
add_index :event_engine_store_stored_events, :occurred_at
add_index :event_engine_store_stored_events, :idempotency_key
```

---

## Querying the log

The model ships with **no scopes** — query it with plain ActiveRecord:

```ruby
SE = EventEngine::Store::StoredEvent

SE.where(event_name: "order_placed")
SE.where("occurred_at > ?", 7.days.ago)
SE.where(aggregate_type: "Order", aggregate_id: order.id).order(:id)  # one aggregate's history
SE.order(:id).find_each { |e| … }                                     # full log, batched
SE.pluck(:event_name).tally                                           # quick histogram
```

For richer queries, add your own scopes — see below.

---

## Customizing the store

This is the part most teams need. The store is deliberately minimal, so the
customization seams are explicit. The most common ask — **"I want more columns on the
event table"** — has an important catch, covered first.

### Expanding the table with your own columns

You'll often want first-class columns instead of digging into the `payload`/`metadata`
JSON on every query.

**Why expand the table:**

- **Indexable, fast filtering/joins** — e.g. `actor_id`, `tenant_id`, `correlation_id`
  as real columns you can index and join on, instead of `metadata->>'actor_id'`.
- **Reporting & BI tools** that don't grok JSON columns well.
- **Foreign keys / constraints** to enforce integrity against other tables.
- **Partitioning / retention** by a real column (e.g. `tenant_id`, `created_at`).

Adding a column is **two** steps: a migration adds the column, and you extend the
`Recorder` to populate it (the recorder writes a fixed set of attributes, so a new
column stays `NULL` until the recorder fills it).

**Step 1 — migration** (use a timestamp *after* the gem's `20260605000001`):

```ruby
# db/migrate/20260701000000_extend_stored_events.rb
class ExtendStoredEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :event_engine_store_stored_events, :actor_id,       :integer
    add_column :event_engine_store_stored_events, :tenant_id,      :integer
    add_column :event_engine_store_stored_events, :correlation_id, :string

    add_index :event_engine_store_stored_events, :actor_id
    add_index :event_engine_store_stored_events, [:tenant_id, :created_at]
  end
end
```

**Step 2 — capture the values.** Wrap the recorder so it pulls your new fields out of
each event (typically from `metadata`) in addition to the defaults:

```ruby
# config/initializers/event_engine_store.rb
require "event_engine/store/recorder"

module EventEngine
  module Store
    class Recorder
      # Re-open #call to add columns. Keep the default capture and extend it.
      def call(event)
        meta = event.metadata || {}
        StoredEvent.create!(
          event_name:        event.event_name,
          event_type:        event.event_type,
          event_version:     event.event_version,
          process_type:      event.process_type,
          payload:           event.payload,
          metadata:          event.metadata,
          occurred_at:       event.occurred_at,
          idempotency_key:   event.idempotency_key,
          aggregate_type:    event.aggregate_type,
          aggregate_id:      event.aggregate_id,
          aggregate_version: event.aggregate_version,

          # your added columns:
          actor_id:          meta[:actor_id]      || meta["actor_id"],
          tenant_id:         meta[:tenant_id]     || meta["tenant_id"],
          correlation_id:    meta[:correlation_id] || meta["correlation_id"]
        )
      end
    end
  end
end
```

Now emit with the context in `metadata` and it lands in real columns:

```ruby
EventEngine.order_placed(order: order, metadata: { actor_id: current_user.id, tenant_id: tenant.id })
```

> **Tip — an upgrade-resilient alternative.** Re-opening `Recorder#call` replaces it,
> so it won't pick up changes to the default capture in a future gem version. If you'd
> rather not re-list the defaults, `prepend` a module that lets the gem do its insert
> and then patches your columns on the returned record:
>
> ```ruby
> module CaptureContext
>   def call(event)
>     record = super
>     meta = event.metadata || {}
>     record.update_columns(            # update_columns bypasses the readonly guard
>       actor_id:  meta[:actor_id]  || meta["actor_id"],
>       tenant_id: meta[:tenant_id] || meta["tenant_id"]
>     )
>     record
>   end
> end
> EventEngine::Store::Recorder.prepend(CaptureContext)
> ```
>
> This is resilient to default-capture changes, at the cost of a second write.

### Adding query scopes to the model

Re-open the model to add scopes/helpers (you can't add columns this way — that needs a
migration):

```ruby
# config/initializers/event_engine_store.rb (or app/models/…)
EventEngine::Store::StoredEvent.class_eval do
  scope :named,         ->(name) { where(event_name: name) }
  scope :for_aggregate, ->(type, id) { where(aggregate_type: type, aggregate_id: id).order(:id) }
  scope :since,         ->(time) { where("occurred_at >= ?", time) }
end

EventEngine::Store::StoredEvent.named("order_placed").since(1.day.ago)
```

### Recording only some events

The default records everything. To record a subset, prepend a filter that skips the
rest:

```ruby
module RecordDomainOnly
  RECORDED = %w[order_placed payment_captured].freeze
  def call(event)
    return unless RECORDED.include?(event.event_name.to_s)
    super
  end
end
EventEngine::Store::Recorder.prepend(RecordDomainOnly)
```

**Why:** keep the log focused on domain/audit-worthy events and avoid recording noisy
system events.

### Replacing the recorder entirely

For a fundamentally different write path (a different table, sharding, an external
audit service), register your own handler and turn off the default one:

```ruby
class MyAuditRecorder
  def call(event)
    AuditLog.create!(kind: event.event_name, data: event.payload, at: event.occurred_at)
  end
end

Rails.application.config.after_initialize do
  EventEngine.register_handler(MyAuditRecorder.new, process_types: :all)
end
```

(See [Disabling the default recorder](#disabling-the-default-recorder) to stop the
built-in one from also writing.)

### Disabling the default recorder

There's no config flag to skip it, so neutralize it in an initializer. Cleanest is to
make `Recorder#call` a no-op:

```ruby
module DisableDefaultRecorder
  def call(_event); end
end
EventEngine::Store::Recorder.prepend(DisableDefaultRecorder)
```

> Avoid `EventEngine.reset_handlers!` for this — it clears **all** handlers, including
> `event_engine-delivery`'s and the projection dispatcher. Only reach for it if you're
> fully taking over routing.

### Making recording resilient / async

The default `Recorder` calls `StoredEvent.create!` **synchronously** inside dispatch.
A DB hiccup will therefore raise straight back into your emitting code. If recording
must never break emission, wrap it to rescue (and optionally enqueue a retry):

```ruby
module ResilientRecord
  def call(event)
    super
  rescue => e
    Rails.logger.error("[store] failed to record #{event.event_name}: #{e.class} #{e.message}")
    # optional: RecordEventLaterJob.perform_later(event.to_h)
    nil
  end
end
EventEngine::Store::Recorder.prepend(ResilientRecord)
```

**Trade-off:** rescuing protects emission but means a recording failure no longer
surfaces loudly — make sure you alert on the log line.

---

## Replay

`EventEngine::Store::Replay.each` reconstructs `EventEngine::Event` objects from the
log in append order (ordered by `id`, batched via `find_each`):

```ruby
EventEngine::Store::Replay.each do |event|
  # event is an EventEngine::Event rebuilt from its row
  puts "#{event.occurred_at} #{event.event_name}"
end

# Without a block you get an Enumerator (a *live* query, not a snapshot):
enum = EventEngine::Store::Replay.each
enum.count
```

A replayed event differs from the one that was dispatched:

- `payload` and `metadata` have **string keys**, because they are read back from JSON
  columns (`event.payload["weight"]`, not `event.payload[:weight]`).
- `event_name` and `process_type` are **strings**, read back from string columns.
- `subject` and `domain` are **nil**, because the table has no columns for them.

Use replay to rebuild read models, backfill a new projection, or audit history.

---

## Projections

A projection is any object with `apply(event)`. Register it and it's updated **live**
as events are dispatched, and can be **rebuilt** from the full log on demand.

```ruby
class OrdersByDay
  def initialize; @counts = Hash.new(0); end
  attr_reader :counts

  def apply(event)
    @counts[event.occurred_at.to_date] += 1 if event.event_name.to_s == "order_placed"
  end
end

projection = OrdersByDay.new
EventEngine::Store.register_projection(projection)   # live updates from now on

EventEngine::Store.rebuild(projection)               # replay the whole log into it
EventEngine::Store.reset_projections!                # clear all (e.g. in tests)
```

API: `register_projection(p)`, `projections`, `reset_projections!`, `rebuild(p)`.

**Why projections:** maintain a denormalized read model (counters, dashboards,
search indexes) that you can always recompute from the authoritative log — the core
event-sourcing payoff.

> **Note:** projections run **synchronously inside dispatch**. If a projection's
> `apply` raises, it propagates and can break event emission (and stops later
> handlers). Keep `apply` fast and defensive; for heavy work, have `apply` enqueue a
> job instead of doing the work inline.

---

## License

Available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
