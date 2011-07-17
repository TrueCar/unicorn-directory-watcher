# Unicorn Directory Watcher

Unicorn wrapper that restarts the server when a file changes (inspired by http://namelessjon.posterous.com/?tag=unicorn)

## Installation

    gem install unicorn-directory-watcher

## Usage

    #!/usr/bin/env ruby
    require 'rubygems'
    require 'unicorn_directory_watcher'

    app_name = "my-app"
    root_dir = File.expand_path("#{File.dirname(__FILE__)}/..")

    UnicornDirectoryWatcher.call(
      app_name,
        root_dir,
        :pid_file => "#{root_dir}/tmp/pids/unicorn.pid",
        :watcher_globs => {
          root_dir => "{app,lib,services,vendor}/**/*.rb"
        }
    ) do
      system "unicorn -D -E development -c config/unicorn.rb config.ru"
    end
