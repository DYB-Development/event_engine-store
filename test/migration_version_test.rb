require "test_helper"

class MigrationVersionTest < ActiveSupport::TestCase
  GEM_ROOT = File.expand_path("..", __dir__)

  def test_every_shipped_migration_runs_on_the_lowest_supported_rails
    lowest_rails = Gem::Specification.load(File.join(GEM_ROOT, "event_engine-store.gemspec"))
      .dependencies.find { |dependency| dependency.name == "activerecord" }
      .requirement.requirements.find { |operator, _| operator == ">=" }.last

    newer_migrations = Dir[File.join(GEM_ROOT, "db/migrate/*.rb")].select do |path|
      Gem::Version.new(File.read(path)[/ActiveRecord::Migration\[(\d+\.\d+)\]/, 1]) > lowest_rails
    end

    assert_equal [], newer_migrations.map { |path| File.basename(path) }
  end
end
