---
name: event_engine-install
description: Use to hook event_engine into a Rails app — adding the gem, writing the `EventEngine.configure` initializer, and getting the boot-time schema catalog in place.
tools: Bash, Read, Edit
scope: events — registering processors and publishers, building the schema catalog, and directing emitted events to the right processor
---

This local follows the steps below exactly, in order, and invents none. Where a
step names a decision, it asks the developer instead of choosing.

## What event_engine is

A Rails engine that loads a committed catalog of event schemas at boot so an app
can emit checked, routed events — hook it in when an app needs its events to be a
declared, reviewable contract.

## Interface

- `EventEngine.configure` — yields the configuration object. The one setup call a
  host app makes; put it in an initializer so it runs at boot.

## How to use it

1. Add the gem to the host app's `Gemfile`:

   ```ruby
   gem "event_engine"
   ```

   Ask the developer whether to take the released gem, pin a version, or track
   the source repository (`github: "DYB-Development/event_engine"`) — do not pick
   for them. The host must be a Rails app; this gem is a Rails engine and does
   nothing outside one.

2. Install it:

   ```bash
   bundle install
   ```

3. Create `config/initializers/event_engine.rb` in the host app:

   ```ruby
   require "event_engine"

   EventEngine.configure do |config|
   end
   ```

   Every setting is optional — an empty block is a valid install. Steps 4 and 5
   fill it in.

4. Decide `metadata_defaults` with the developer. It takes a callable returning a
   hash, invoked on every emit, and its keys are merged **under** any metadata
   passed at the call site, so the call site wins on a collision. There is no safe
   default: ask what belongs on every event this app emits (request id, actor,
   deploy version, …), and leave it unset if the answer is nothing.

   ```ruby
   config.metadata_defaults = -> { { request_id: Current.request_id } }
   ```

   A callable that raises is swallowed and logged rather than breaking the emit.

5. Set `logger` only if the engine's own output should go somewhere other than
   `Rails.logger` — it defaults to `Rails.logger` inside a Rails app.

   ```ruby
   config.logger = Logger.new("log/event_engine.log")
   ```

6. Get the schema catalog to `db/event_schema.json` in the host app and commit it.
   The engine reads that exact path at boot; the path is fixed and no setting
   moves it. Without the file, the app logs a warning in `development` and `test`
   and **refuses to boot in every other environment**. Building the catalog from
   the app's event packs is the `event_engine-develop` local's job — hand off to
   it, and confirm the file exists before treating this install as done.

7. Verify the app boots with the catalog loaded:

   ```bash
   bin/rails runner 'puts EventEngine.schema_registry.loaded?'
   ```

   `true` means the initializer ran and the catalog was read. `false` means the
   catalog file is missing — go back to step 6.

## Conventions

- The initializer is the only host file this local writes, plus one `Gemfile`
  line. It creates no migrations and no tables.
- Re-running any step is safe. Editing the initializer requires an app restart to
  take effect; nothing re-reads it at runtime.
- If `db/event_engine_helpers.rb` is present in the host app, the engine loads it
  at boot. It never creates that file — an event pack commits it. Do not write one.
- Out of scope for this local: everything an app does *with* the engine —
  registering processors, publishers or handlers, choosing how events route,
  pointing the engine at schema sources, emitting events, and the catalog tasks.
  All of that belongs to `event_engine-develop`.
