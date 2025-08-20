# frozen_string_literal: true

require_relative "lib/zirp/version"

Gem::Specification.new do |spec|
  spec.name = "zirp"
  spec.version = Zirp::VERSION
  spec.authors = ["Chris Davis"]
  spec.email = ["chrisdavis179@gmail.com"]

  spec.summary = "Zirp - A powerful release notes and notification tool"
  spec.description = "Zirp is a comprehensive tool for creating and distributing product release notes with video demos and multi-channel notifications (Slack, Email, Twitter, LinkedIn)"
  spec.homepage = "https://github.com/zirp-ai/zirp_rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "slack-ruby-block-kit", "~> 0.20.0"
  spec.add_dependency "slack-ruby-client", "~> 2.1.0"
  spec.add_dependency "nokogiri", "~> 1.15.0"
  spec.add_dependency "mail", "~> 2.8.1"
  
  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
end
