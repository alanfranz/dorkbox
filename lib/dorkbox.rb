require 'socket'
require 'securerandom'
require 'yaml'
require 'tempfile'
require 'shellwords'

require_relative 'bashlike'

include BashLike

USAGE = '

MISSING:
- notification on conflict/error
- some shell escaping for bashlike/sanitize possible names
- something to show other clients and status
- better docs/verbosity
- random delay option for sync_all_tracked: otherwise unneeded conflicts can arise quite often
and set such random delay for cronjob
- logging
-.id configurations: make sure we don\'t get duplicates
- something to solve conflicts and go on
- better way to configure file paths for test purposes
'

module Dorkbox

  LOCKFILE_NAME='.dorkbox.lock'
  CONFLICT_STRING='CONFLICT_MUST_MANUALLY_MERGE'
  GITIGNORE='.gitignore'
  DORKBOX_CONFIG_PATH = File.join(Dir.home, ".dorkbox.yml")
  DORKBOX_CONFIG_LOCK = DORKBOX_CONFIG_PATH + '.lock'
  DORKBOX_CRONTAB_COMMENT = '# dorkbox sync cronjob'

  class InterProcessLock

    def initialize(lock_path)
      @lock_path = lock_path
    end

    def exclusive(&block)
      if block.nil?
        raise ArgumentError, "Block is mandatory"
      end

      lockfile = File.open(@lock_path, File::RDWR|File::CREAT, 0644)
      lockfile.flock(File::LOCK_EX)
      begin
        block.call()
      ensure
        lockfile.flock(File::LOCK_UN)
        lockfile.close()
      end
    end
  end

  class Git
    attr_reader :root_repository_dir

    # this performs the 'git init' command
    def self.init(root_repository_dir)
      escaped = Shellwords.escape(root_repository_dir)
      c("git init #{escaped}")
      Git.new(escaped)
    end

    # this is the actual object constructor
    def initialize(root_repository_dir)
      @root_repository_dir = root_repository_dir
      @git_command = self.class.generate_git_command(root_repository_dir)
      # just check whether repository is valid
      cmd('status')
    end

    def cmd(*args)
      escaped = Shellwords.join(args)
      c("#{@git_command} #{escaped}")
    end

    private

    def self.generate_git_command(local_directory)
      abs_local_directory = File.expand_path(local_directory)
      escaped_localdir = Shellwords.escape(abs_local_directory)
      escaped_gitdir = Shellwords.escape(File.join(abs_local_directory, '.git'))
      "git --work-tree=#{escaped_localdir} --git-dir=#{escaped_gitdir}".freeze()
    end
  end

  class Repository
    attr_reader :localdir, :client_id

    def self.create_new(local_directory, remote_url)
      log "Will create new dorkbox-enabled repository in local directory. Remote #{remote_url} should exist and be empty."
      if Dir.exists?(File.join(local_directory, '.git'))
        raise StandardError.new("preexisting git repository found.")
      end
      git = Git.init(local_directory)
      File.open(File.join(local_directory, GITIGNORE), 'a') { |f|
        f.puts(Dorkbox::CONFLICT_STRING)
        f.puts(Dorkbox::LOCKFILE_NAME)
      }
      git.cmd('remote', 'add', 'dorkbox', remote_url)
      git.cmd('add', Dorkbox::GITIGNORE)
      git.cmd('commit', '-m', 'enabling dorkbox')

      configure_repository(git, local_directory)
    end

    def self.configure_repository(git, local_directory)
      dorkbox_client_id = configure_client_id(git)
      align_client_ref_to_master(git, dorkbox_client_id)
      git.cmd('push', '-u', 'dorkbox', 'master', dorkbox_client_id)
      repo = Repository.new(local_directory)
      repo.track()
      repo
    end

    def self.connect_existing(local_directory, remote_url)
      log "Will create new git repo in local directory and connect to remote existing dorkbox repository #{remote_url}"
      if Dir.exists?(File.join(local_directory, '.git'))
        raise StandardError.new("preexisting git repository found.")
      end
      git = Git.init(local_directory)
      git.cmd('remote', 'add', 'dorkbox', remote_url)
      git.cmd('fetch', '--all')
      git.cmd('checkout', 'master')

      configure_repository(git, local_directory)
    end

    def initialize(local_directory)
      abs_local_directory = File.expand_path(local_directory)
      # todo: check local config for dorkbox-enabling
      if !(Dir.exists?(abs_local_directory) &&
          File.readable?(abs_local_directory) &&
          File.writable?(abs_local_directory) &&
          File.executable?(abs_local_directory) &&
          Dir.exists?(File.join(abs_local_directory, '.git'))
      )
        raise StandardError.new("#{abs_local_directory} is not a valid dorkbox-enabled repository")
      end
      if abs_local_directory.include?('alan')
        raise StandardError.new("mayday")
      end
      @git = Git.new(abs_local_directory)
      @localdir = abs_local_directory
      @conflict_string = File.join(abs_local_directory, Dorkbox::CONFLICT_STRING)
      @client_id = @git.cmd('config', '--local', '--get', 'dorkbox.client-id').strip()
      @sync_lock = Dorkbox::InterProcessLock.new(File.join(@localdir, Dorkbox::LOCKFILE_NAME))
      @track_lock = Dorkbox::InterProcessLock.new(Dorkbox::DORKBOX_CONFIG_LOCK)
    end

    def sync
      @sync_lock.exclusive() {
        if File.exists?(@conflict_string)
          log "Conflict found, not syncing."
          raise StandardError.new("Conflict found, not syncing.")
        end
        @git.cmd('fetch', '--all')
        @git.cmd('add', '-A')
        any_change = @git.cmd('diff', '--staged').strip()
        if !any_change.empty?
          @git.cmd('commit', '-m', 'Automatic dorkbox commit')
        end
        begin
          @git.cmd('merge', '--ff-only', 'dorkbox/master')

          self.class.align_client_ref_to_master(@git, @client_id)
          @git.cmd('push', 'dorkbox', 'master', @client_id)
        rescue
          # TODO: check which error actually happens and think about
          # a solving strategy.
          log "Error while syncing, stopping until solved."
          FileUtils.touch(@conflict_string)
          raise StandardError.new("Conflict found, syncing stopped.")
        end
        log "sync succeeded"
      }
    end

    def track
      @track_lock.exclusive() {
        begin
          cfg = YAML.load_file(DORKBOX_CONFIG_PATH)
        rescue Errno::ENOENT
          cfg = {:track => []}
        end
        cfg[:track].push(@localdir)
        cfg[:track].uniq!
        File.open(DORKBOX_CONFIG_PATH, 'w') { |f| f.write(cfg.to_yaml) }
      }
    end

    def untrack
      @track_lock.exclusive() {
        begin
          cfg = YAML.load_file(DORKBOX_CONFIG_PATH)
        rescue Errno::ENOENT
          cfg = {:track => []}
        end
        cfg[:track].delete(@localdir)
        cfg[:track].uniq!
        File.open(DORKBOX_CONFIG_PATH, 'w') { |f| f.write(cfg.to_yaml) }
      }
    end

    private

    def self.configure_client_id(git)
      dorkbox_client_id = 'dorkbox-' + Socket.gethostname() + "-" + SecureRandom.urlsafe_base64(5)
      git.cmd('config', '--local', 'dorkbox.client-id', dorkbox_client_id)
      dorkbox_client_id
    end

    def self.align_client_ref_to_master(git, dorkbox_client_id)
      git.cmd('update-ref', "refs/heads/#{dorkbox_client_id}", 'master')
    end


  end

  def self.sync_all_tracked
    begin
      cfg = YAML.load_file(DORKBOX_CONFIG_PATH)
    rescue Errno::ENOENT
      return
    end
    # TODO: don't crash if one syncing fails!
    cfg[:track].each { |d|
      begin
        Repository.new(d).sync()
      rescue
        log "Error while syncing repository #{d}"
      end
    }
  end

  def self.enable_dorkbox_cronjob(executable=File.join(File.dirname(File.expand_path(__FILE__)), '..', 'bin', 'dorkbox'))

    cron_start = "#{DORKBOX_CRONTAB_COMMENT} start\n"
    cron_end = "#{DORKBOX_CRONTAB_COMMENT} end\n"
    old_crontab = c('crontab -l 2>/dev/null || true')
    old_crontab.sub!(/#{cron_start}.*?#{cron_end}/m, '')

    tmp = Tempfile.new("dorkbox-temp")
    if (old_crontab.size > 0) && (old_crontab[-1] != "\n")
      old_crontab.concat("\n")
    end

    old_crontab.concat(cron_start).concat("*/5 * * * * #{Shellwords.escape(executable)} sync_all_tracked\n").concat(cron_end)
    tmp.puts(old_crontab)
    tmp.flush()
    `crontab #{tmp.path}`
    tmp.close()
  end

  def self.cleanup_tracked
    begin
      cfg = YAML.load_file(DORKBOX_CONFIG_PATH)
    rescue Errno::ENOENT
      return
    end
    # TODO: check for dorkbox-enabled dir, e.g. try retrieving client id
    cfg[:track].select! { |d| Dir.exists?(d) }
    File.open(DORKBOX_CONFIG_PATH, 'w') { |f| f.write(cfg.to_yaml) }
  end


  def self.test
    require 'dorkbox_test'
    MiniTest::Unit.autorun
  end

end
