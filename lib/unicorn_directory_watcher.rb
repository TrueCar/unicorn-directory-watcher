require 'fileutils'
require 'directory_watcher'

module UnicornDirectoryWatcher
  def self.call(*args, &block)
    Runner.new(*args).call(&block)
  end

  class Runner
    attr_reader :app_name, :root_dir, :watcher_globs, :log_dir, :pid_dir

    def initialize(app_name, root_dir, params={})
      @app_name, @root_dir = app_name, root_dir
      @watcher_globs = params[:watcher_globs] || {
        root_dir => "{app,lib,vendor}/**/*.rb"
      }
      @log_dir = (params[:log_dir] || "#{root_dir}/log").tap do |dir|
        FileUtils.mkdir_p(dir)
      end
      @pid_dir = (params[:pid_dir] || "#{root_dir}/tmp/pids").tap do |dir|
        FileUtils.mkdir_p(dir)
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

      # get the pid
      system "touch #{pidfile}"

      master_pid = lambda do
        File.open(pidfile) { |f| f.read }.chomp.to_i
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
    def pidfile
      "#{pid_dir}/unicorn.pid"
    end
  end
end
