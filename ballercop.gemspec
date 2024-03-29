# frozen_string_literal: true

require_relative "lib/ballercop/version"

Gem::Specification.new do |spec|
  spec.name          = "ballercop"
  spec.version       = Ballercop::VERSION
  spec.authors       = ["Olu"]
  spec.email         = ["olu@baller.tv"]

  spec.summary       = "BallerTV's rubocop"
  spec.homepage      = "https://ballertv.com"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ballertv/ballercop"
  spec.metadata["changelog_uri"] = "https://github.com/ballertv/ballercop/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "activesupport"
  spec.add_dependency "rugged"
  spec.add_dependency "rubocop", '~> 1.32'
  spec.add_dependency "securerandom"
  spec.add_dependency "thor"
  spec.add_dependency "slack-notifier"
  spec.add_dependency "platform-api"
  spec.add_development_dependency "pry"
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "cucumber"
  spec.add_development_dependency "aruba"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
