# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hoick/version'

Gem::Specification.new do |spec|
  spec.name          = "hoick"
  spec.version       = Hoick::VERSION
  spec.authors       = ["Mike Williams"]
  spec.email         = ["mdub@dogbiscuit.org"]
  spec.summary       = %q{A command-line HTTP client}
  spec.description   = File.read("README.md").split("\n\n")[1]
  spec.homepage      = "https://github.com/mdub/hoick"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mime-types", "~> 1.22"

end
