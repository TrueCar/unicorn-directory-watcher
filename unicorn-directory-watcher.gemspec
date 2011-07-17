# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'unicorn_directory_watcher/version'

Gem::Specification.new do |s|
  s.name        = "unicorn-directory-watcher"
  s.version     = ::UnicornDirectoryWatcher::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Brian Takita"]
  s.email       = ["btakita@truecar.com"]
  s.homepage    = "https://github.com/TrueCar/unicorn-directory-watcher"
  s.summary     = %q{Unicorn wrapper that restarts the server when a file changes (inspired by http://namelessjon.posterous.com/?tag=unicorn)}
  s.description = %q{Unicorn wrapper that restarts the server when a file changes (inspired by http://namelessjon.posterous.com/?tag=unicorn)}

  s.required_rubygems_version = ">= 1.3.6"

  # Man files are required because they are ignored by git
  s.files              = `git ls-files`.split("\n")
  s.test_files         = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths      = ["lib"]

  s.add_dependency "directory_watcher", ">=1.4.0"
  s.add_dependency "eventmachine", ">=0.12"
  s.add_dependency "rev", ">=0.3.2"

  s.add_development_dependency "sinatra", ">=1.2.6"
end
