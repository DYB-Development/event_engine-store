require_relative "lib/event_engine/store/version"

Gem::Specification.new do |spec|
  spec.name        = "event_engine-store"
  spec.version     = EventEngine::Store::VERSION
  spec.authors     = [ "tylercschneider" ]
  spec.email       = [ "tylercschneider@gmail.com" ]
  spec.homepage    = "https://github.com/DYB-Development/event_engine-store"
  spec.summary     = "Permanent, queryable event record for EventEngine"
  spec.description = "The durable record layer for EventEngine: an immutable, append-only event table the host owns, a handler that records every dispatched event, and event-sourcing replay. Depends on event_engine for event definitions."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/tylercschneider/event_engine-store/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/tylercschneider/event_engine-store/issues"
  spec.metadata["documentation_uri"] = "https://github.com/tylercschneider/event_engine-store#readme"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,the_local}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "railties", ">= 7.1.6", "< 9"
  spec.add_dependency "activerecord", ">= 7.1.6", "< 9"
  spec.add_dependency "event_engine", ">= 0.2.1"

  # json 3 dropped the second argument ActiveSupport::JSON.decode passes it, so
  # every read of a json column raises until Rails ships a release that calls
  # the new interface.
  spec.add_dependency "json", "< 3"
end
