---
name: event_engine-develop
description: Use PROACTIVELY for wiring an app's event processing on event_engine — registering processors and handlers, routing events to the right processor, building the committed schema catalog from event packs, and printing the catalog — MUST BE USED instead of hand-rolling event dispatch, a processor lookup table, or a script that stitches pack schemas together.
tools: Read, Write, Edit, Grep
scope: events — registering processors and publishers, building the schema catalog, and directing emitted events to the right processor
---

This local wires a host app's event processing on event_engine, following the
steps below in order. Where a step names a decision, it asks the developer
instead of choosing.

## What event_engine is

A Rails engine that loads a committed catalog of event schemas at boot, turns an
event pack's raw inputs into a checked event, sends that event to exactly one
**processor**, and then to every matching **handler**. Fire this local when an app
needs its events built, routed, or catalogued — anything from "our pack's events
aren't reaching the subscriber" to "add the new pack's schema to the app".

## Interface

- `publisher_schema_paths` — configuration setting; the list of pack `schema.json`
  files the catalog is built from. Defaults to empty.
- `bin/rails event_engine:schema:catalog` — reads every `publisher_schema_paths`
  source and writes them into the app's committed catalog at `db/event_schema.json`.
- `EventEngine.register_processor` — registers a processor under a name, so a
  routing setting can point at that name.
- `event_processors` — configuration setting; a hash of event name → processor
  name. The most specific routing rule.
- `domain_processors` — configuration setting; a hash of domain → processor name.
  Applies to every event in that domain.
- `default_processor` — configuration setting; the processor name used when no
  event or domain rule matches.
- `EventEngine.register_handler` — registers a handler that runs after the
  processor, filtered by the event's process type.
- `EventEngine.register_definition_publisher!` — points a pack's publisher port at
  event_engine, so the pack's helpers produce real events. Runs automatically at
  boot; call it directly only for a port other than the default.
- `bin/rails event_engine:catalog` — prints the catalogued events as markdown.

## How to use it

All configuration below goes in the host app's
`config/initializers/event_engine.rb`, on the configuration object yielded inside
it. The `event_engine-install` local creates that file — if it is missing, hand
off to that local first and come back.

1. Set `publisher_schema_paths` to the `schema.json` of every pack whose events
   this app handles. Ask the developer which packs are in scope; do not infer the
   list from the Gemfile, and do not guess a path.

   ```ruby
   config.publisher_schema_paths = [
     MarketingEvents.schema_path,
     SalesEvents.schema_path
   ]
   ```

   Leave this unset and step 2 writes an empty catalog — no event is emittable.

2. Build the catalog and commit it:

   ```bash
   bin/rails event_engine:schema:catalog
   ```

   It writes `db/event_schema.json` from the sources, in order, overwriting the
   file. It never edits a source, and it never recomputes a schema's fingerprint —
   what a pack published is what lands. Commit the result; the app reads that file
   at boot, warns in `development` and `test` when it is absent, and refuses to
   boot in every other environment. Re-run it whenever a pack's schema changes or
   a pack is added to step 1.

3. Register each processor by name, in the initializer, so the names exist before
   any event is emitted. A processor is anything responding to `#call(event)`:

   ```ruby
   EventEngine.register_processor(:subscribers, MyApp::SubscriberProcessor)
   ```

   Registering the same name twice replaces the earlier one.

4. Route events to those processors with the three settings. Ask the developer how
   their events should route — there is no safe default, and the right answer
   depends on which processors the app actually runs:

   ```ruby
   config.default_processor = :subscribers
   config.domain_processors = { marketing: :delivery }
   config.event_processors  = { lead_created: :telemetry }
   ```

   Resolution is `event_processors[event_name]`, then
   `domain_processors[domain]`, then `default_processor` — first match wins.
   Every name used here must be registered in step 3.

5. Register handlers. A handler is anything responding to `#call(event)`, and it
   runs after the processor. `process_types:` is required — either `:all`, or a
   list of process types that is matched against the event's own process type:

   ```ruby
   EventEngine.register_handler(MyApp::AuditLog, process_types: %i[durable broker])
   EventEngine.register_handler(MyApp::Firehose, process_types: :all)
   ```

   Every handler whose filter matches runs, in registration order. An event with
   no matching handler is still built and processed.

6. Leave the publisher port alone unless the app has one of its own. At boot the
   engine points the default port at event_engine, which is what makes a pack's
   generated helper produce a real event instead of raising. Call it directly only
   to install it on a different port object:

   ```ruby
   EventEngine.register_definition_publisher!(MyApp::CustomPort)
   ```

   It is a no-op returning `nil` when the port cannot accept a publisher — which
   is also what happens when no pack is loaded.

7. Verify the wiring:

   ```bash
   bin/rails event_engine:catalog
   ```

   It prints one markdown section per catalogued event — name, version, type,
   subject, payload fields — read from the committed catalog. An event missing
   here will not emit; go back to step 1.

## Conventions

- Both processors and handlers receive the same built event, carrying
  `event_name`, `event_type`, `event_version`, `process_type`, `subject`,
  `domain`, `payload`, `metadata`, `occurred_at`, `idempotency_key`, and the
  `aggregate_type` / `aggregate_id` / `aggregate_version` trio. Read from it; do
  not mutate it.
- The process types a handler filter can name are `inline`, `background`,
  `durable`, `broker`, `telemetry`, and `sourced`. A schema declares one; the
  filter is matched literally, so a typo silently never fires.
- With none of the three routing settings set, no processor runs at all — events
  are built and go straight to handlers. Once **any** of them is set, an event
  matching none of the rules raises `EventEngine::UnroutableEventError` at emit.
  Setting only `domain_processors` for one domain therefore breaks every other
  domain; pair narrow rules with a `default_processor`.
- Routing at a name with no registered processor fails at emit time, not at boot.
  Keep steps 3 and 4 in the same initializer so they cannot drift.
- A pack helper firing an event that is not in the committed catalog raises
  `EventEngine::DefinitionPublisher::EventNotInCatalogError`. That means the
  catalog is stale — rebuild it in step 2, do not work around it in app code.
- Initializer changes need an app restart; nothing is re-read at runtime.
- Out of scope for this local: adding the gem and writing the initializer itself
  (`event_engine-install`), and authoring event definitions or packs — this local
  consumes a pack's published `schema.json`, it never writes one.
