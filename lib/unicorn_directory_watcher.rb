require 'fileutils'
require 'directory_watcher'

module UnicornDirectoryWatcher
  def self.call(*args, &block)
    Runner.new(*args).call(&block)
  end

  class Runner
    attr_reader :app_name, :root_dir, :watcher_globs, :pid_file

    def initialize(app_name, root_dir, params={})
      @app_name, @root_dir = app_name, root_dir
      @watcher_globs = params[:watcher_globs] || {
        root_dir => "{app,lib,vendor}/**/*.rb"
      }
      @pid_file = (params[:pid_file] || "#{root_dir}/tmp/pids/unicorn.pid").tap do |pid_file|
        FileUtils.mkdir_p File.dirname(File.expand_path(pid_file))
      end
    end

    def call(&block)
      if RUBY_PLATFORM =~ /darwin/
        EM.kqueue = true
      else
        EM.epoll = true
      end

      # start the unicorn
      yield(self)

      master_pid = lambda do
        File.exists?(pid_file) ? File.read(pid_file).strip.to_i : nil
      end

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

        dw
      end

        # wrap this in a lambda, just to avoid repeating it
      stop = lambda { |sig|
        master_pid.call.tap do |pid|
          Process.kill :QUIT, pid if pid
        end
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
  end
end
