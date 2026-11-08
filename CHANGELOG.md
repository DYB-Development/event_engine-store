# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-11-07

### Added

- The gem ships its expert agents, so an app that installs it can ask an event_engine-store expert how events are stored, replayed and built into projections.

### Fixed

- The stored events migration runs on Rails 7.1.

## [0.1.0] - 2026-07-29

First published release of `event_engine-store`, the durable event record for the
EventEngine pipeline.

### Added

- `StoredEvent` — an immutable, append-only table the host owns, with a migration
  installed via the engine.
- `Recorder` — a handler registered for every process type, so every dispatched event
  is written to the record regardless of how it is otherwise processed.
- `ProjectionDispatcher` — a handler that feeds recorded events to projections.
- `Replay` — reconstructs `EventEngine::Event` objects from the stored record for
  event sourcing.

### Notes

- Requires `event_engine >= 0.2.1`. `0.2.0` and earlier raise `UnroutableEventError`
  on emit once a catalog has been built, which breaks apps like this one that process
  events through handlers rather than a per-event processor.
- These are **handlers**, not processors. `event_engine` routes each event to at most
  one processor, named in the host's rules file; a recorder needs to observe every
  event, which is what a handler does. An app using only this gem leaves its rules
  file undecided and nothing routes — the handlers still fire.
