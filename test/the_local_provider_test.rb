require "test_helper"
require "the_local/provider_check"

class TheLocalProviderTest < ActiveSupport::TestCase
  GEM_ROOT = File.expand_path("..", __dir__)

  def test_the_committed_locals_match_the_manifest
    assert_equal [], TheLocal::ProviderCheck.new(GEM_ROOT).problems
  end

  def test_the_packaged_gem_ships_the_locals
    spec = Gem::Specification.load(File.join(GEM_ROOT, "event_engine-store.gemspec"))

    assert_includes spec.files, "the_local/agents/event_engine-store-develop.md"
  end
end
