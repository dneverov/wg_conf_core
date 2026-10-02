# frozen_string_literal: true

require_relative "lib/wg_conf_core/version"

Gem::Specification.new do |spec|
  spec.name    = "wg_conf_core"
  spec.version = WgConfCore::VERSION
  spec.authors = ["Denis Neverov"]
  spec.email   = ["denis.neverov@gmail.com"]

  spec.summary     = "Core backend logic for AmneziaWG and WireGuard CLI tools."
  spec.description = "Handles directory synchronization, sequential ping testing, status evaluation, and interface runner controls."
  spec.homepage    = "https://github.com/dneverov/wg_conf_core"
  spec.required_ruby_version = ">= 2.6.0"

  # Жестко блокируем случайный публичный push на rubygems.org из соображений безопасности
  spec.metadata["allowed_push_host"] = "http://localhost"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "https://github.com/dneverov/wg_conf_core/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.license = "MIT"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
