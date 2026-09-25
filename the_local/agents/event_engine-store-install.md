---
name: event_engine-store-install
description: Use to hook event_engine-store into a Rails app — adding the gem, copying and running its stored-events migration, and confirming dispatched events are being recorded.
tools: Bash, Read, Edit
scope: event store — recording every dispatched event to an append-only table, replaying the log in order, and rebuilding projections from it
---

This local follows the steps below exactly, in order, and invents none. Where a
step names a decision, it asks the developer instead of choosing.

## What event_engine-store is

A Rails engine that records every event event_engine dispatches into an
append-only table in the host app — hook it in when an app needs a permanent,
replayable log of its events.

## Interface

- `bin/rails event_engine_store:install:migrations` — copies the migration that creates the
  `event_engine_store_stored_events` table into the host app's `db/migrate/`.

## How to use it

1. Confirm event_engine is already installed in the host app — its initializer
   exists and the app boots with its schema catalog. If not, hand off to the
   `event_engine-install` local first and come back. This gem requires
   `event_engine` 0.2.1 or later.

2. Add the gem to the host app's `Gemfile`:

   ```ruby
   gem "event_engine-store"
   ```

   Ask the developer whether to take the released gem, pin a version, or track the
   source repository (`github: "DYB-Development/event_engine-store"`) — do not
   pick for them. The host must be a Rails app; this gem is a Rails engine.

3. Install it:

   ```bash
   bundle install
   ```

4. Copy the migration into the host app:

   ```bash
   bin/rails event_engine_store:install:migrations
   ```

   It writes one new file under `db/migrate/` that creates
   `event_engine_store_stored_events`. The command copies pending migrations from
   every installed engine, not only this one — show the developer the list of new
   files before continuing.

5. Check the host's Rails version. The copied migration is declared as
   `ActiveRecord::Migration[8.1]`, which Rails versions before 8.1 reject. If the
   host runs an older Rails, ask the developer whether to change the bracketed
   version in the copied file to the host's own Rails version — do not change it
   without asking.

6. Run the migration and commit both the migration and the updated schema file:

   ```bash
   bin/rails db:migrate
   ```

7. Verify the table exists:

   ```bash
   bin/rails runner 'p ActiveRecord::Base.connection.table_exists?("event_engine_store_stored_events")'
   ```

   `true` means the install is done. `false` means step 6 did not run against
   this environment's database.

8. Verify recording. In a Rails console, note
   `ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM event_engine_store_stored_events")`,
   emit any catalogued event the app already emits, and read the count again. It
   grows by one per dispatched event.

## Conventions

- There is no generator, no initializer, and no configuration. Once the gem is in
  the bundle and the table exists, every dispatched event is recorded at boot
  without any host code.
- Recording is synchronous and inside the emit call, so an emit fails if the
  table is missing. Do not deploy the gem to an environment before its migration
  has run there.
- The table has no foreign keys and no unique index. The idempotency key is
  indexed but not unique, so a duplicate emit is recorded twice.
- Re-running step 4 copies nothing that is already in `db/migrate/`.
- Out of scope for this local: querying or replaying the log, projections, and
  changing what gets recorded. All of that belongs to `event_engine-store-develop`.
