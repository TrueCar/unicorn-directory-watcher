#!/usr/bin/env ruby
require 'rubygems'
require "bundler"
$:.unshift(File.expand_path("#{File.dirname(__FILE__)}/../lib"))
require 'unicorn_directory_watcher'

app_name = "unicorn-watcher"
root_dir = File.expand_path("#{File.dirname(__FILE__)}/..")

UnicornDirectoryWatcher.call(
  app_name,
    root_dir,
    :watcher_globs => {
      root_dir => "{app,lib,services,vendor}/**/*.rb"
    }
) do
  system "unicorn -D -E development -c config/unicorn.rb config.ru"
end
