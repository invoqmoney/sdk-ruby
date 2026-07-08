# frozen_string_literal: true

require_relative "lib/invoq/version"

Gem::Specification.new do |spec|
  spec.name = "invoq"
  spec.version = Invoq::VERSION
  spec.authors = ["invoq"]

  spec.summary = "Ruby SDK for invoq stablecoin payment acceptance."
  spec.description = "Ruby SDK for invoq server APIs and webhook verification."
  spec.homepage = "https://rubygems.org/gems/invoq"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org"
  }

  spec.files = Dir.glob("lib/**/*.rb") + %w[LICENSE.txt README.md]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", ">= 10.0", "< 14.0"
end
