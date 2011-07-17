require 'fileutils'
require 'directory_watcher'

module UnicornDirectoryWatcher
  def self.call(*args, &block)
    Runner.new(*args).call(&block)
  end

  class Runner
    attr_reader :app_name, :root_dir, :watcher_globs

    def initialize(app_name, root_dir, params={})
      @app_name, @root_dir = app_name, root_dir
      @watcher_globs = params[:watcher_globs] || {
        root_dir => "{app,lib,vendor}/**/*.rb"
      }
    end

    def call(&block)
      if RUBY_PLATFORM =~ /darwin/
        EM.kqueue = true
      else
        EM.epoll = true
      end

      FileUtils.mkdir_p("#{root_dir}/log")
      ENV["UNICORN_STDERR_PATH"] = "#{root_dir}/log/#{app_name}.development.stderr.log"
      ENV["UNICORN_STDOUT_PATH"] = "#{root_dir}/log/#{app_name}.development.stdout.log"

      tail_stderr_log = fork do
        system "tail -f #{ENV["UNICORN_STDERR_PATH"]}"
      end

        # remove the old log
      system "rm -f -- #{logfile}"

      # start the unicorn
      yield

        # get the pid
      system "touch #{pidfile}"

      master_pid = lambda do
        File.open(pidfile) { |f| f.read }.chomp.to_i
      end

      system "touch #{logfile}"

      directory_watchers = watcher_globs.map do |dir, glob|
        # watch our app for changes
        dw = DirectoryWatcher.new dir,
          :glob => glob,
          :scanner => :em,
          :pre_load => true

          # SIGHUP makes unicorn respawn workers
        dw.add_observer do |*args|
          old_pid = master_pid.call
          Process.kill :USR2, old_pid
          start = Time.now
          loop do
            raise TimeoutError if Time.now - start > 5
            break if master_pid.call != old_pid
            sleep 0.5
          end
          Process.kill :QUIT, old_pid
        end
        Process.kill :HUP, tail_stderr_log

        dw
      end

        # wrap this in a lambda, just to avoid repeating it
      stop = lambda { |sig|
        Process.kill :QUIT, master_pid.call # kill unicorn
        directory_watchers.each do |dw|
          dw.stop
        end
        exit
      }

      trap("INT", stop)

      directory_watchers.each do |dw|
        dw.start
      end
      sleep
    end

    protected
    def logfile
      "#{root_dir}/log/unicorn.log"
    end

    def pidfile
      "#{root_dir}/tmp/pids/unicorn.pid"
    end
  end
end
