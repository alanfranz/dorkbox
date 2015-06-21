require 'minitest/unit'
require 'minitest/spec'
require 'minitest/mock'
require 'minitest/autorun'
require 'fileutils'
require 'tempfile'
require_relative 'dorkbox'


class TestCreation < MiniTest::Unit::TestCase
  def test_create
    Dir.mktmpdir() { |remote_repo_dir|
      `git init --bare #{remote_repo_dir}`

      Dir.mktmpdir() { |local_dorkbox_repo_dir|
        Dorkbox::Repository.create_new(local_dorkbox_repo_dir, remote_repo_dir)
        assert(File.exists?(File.join(local_dorkbox_repo_dir, Dorkbox::GITIGNORE)))
      }
    }

    Dorkbox::cleanup_tracked()
  end

  def test_connect
    Dir.mktmpdir() { |remote_repo_dir|
      `git init --bare #{remote_repo_dir}`

      first_client_name = nil
      Dir.mktmpdir() { |first_repo_dir|
        first_repo = Dorkbox::Repository.create_new(first_repo_dir, remote_repo_dir)

        Dir.mktmpdir() { |second_repo_dir|
            second_repo = Dorkbox::Repository.connect_existing(second_repo_dir, remote_repo_dir)
            all_branches = c("git --work-tree=#{second_repo_dir} --git-dir=#{File.join(second_repo_dir, '.git')} branch -a")
            assert(all_branches.include?(first_repo.client_id))
            assert(all_branches.include?(second_repo.client_id))
        }
      }
    }
    Dorkbox::cleanup_tracked()
  end
end

class TestSync < MiniTest::Unit::TestCase

  def setup
    Dorkbox::cleanup_tracked()
    @remote_repo_dir = Dir.mktmpdir()
    `git init --bare #{@remote_repo_dir}`

    @first_client_dir = Dir.mktmpdir()
    @second_client_dir = Dir.mktmpdir()
    @third_client_dir = Dir.mktmpdir()

    @first_repo = Dorkbox::Repository.create_new(@first_client_dir, @remote_repo_dir)
    @second_repo = Dorkbox::Repository.connect_existing(@second_client_dir, @remote_repo_dir)
    @third_repo = Dorkbox::Repository.connect_existing(@third_client_dir, @remote_repo_dir)
  end

  def teardown
    FileUtils.remove_entry_secure(@remote_repo_dir)
    FileUtils.remove_entry_secure(@first_client_dir)
    FileUtils.remove_entry_secure(@second_client_dir)
    Dorkbox::cleanup_tracked()
  end

  def test_syncing_between_two_clients
    Dir.chdir(@first_client_dir) {
      File.open("something", "w") { |f| f.write("asd") }
      @first_repo.sync()
    }

    Dir.chdir(@second_client_dir) {
      @second_repo.sync()
      File.open("something") { |f| assert_equal("asd", f.read()) }
    }

    Dir.chdir(@second_client_dir) {
      File.open("something", "a") { |f| f.write("xyz") }
      @second_repo.sync()
    }

    Dir.chdir(@first_client_dir) {
      @first_repo.sync()
      File.open("something", "r") { |f| assert_equal("asdxyz", f.read()) }
    }
  end

  def test_tracking_between_two_clients
    Dir.chdir(@first_client_dir) {
      File.open("something", "w") { |f| f.write("asd") }
      Dorkbox::sync_all_tracked()
    }

    Dir.chdir(@second_client_dir) {
      Dorkbox::sync_all_tracked()
      File.open("something") { |f| assert_equal("asd", f.read()) }
    }

    Dir.chdir(@second_client_dir) {
      File.open("something", "a") { |f| f.write("xyz") }
      Dorkbox::sync_all_tracked()
    }

    Dir.chdir(@first_client_dir) {
      Dorkbox::sync_all_tracked()
      File.open("something", "r") { |f| assert_equal("asdxyz", f.read()) }
    }
  end

  def test_sync_all_tracking_syncs_repos_independently
    Dir.chdir(@first_client_dir) {
      File.open("something", "w") { |f| f.write("asd") }
      Dorkbox::sync_all_tracked()
    }

    Dir.chdir(@first_client_dir) {
      File.open("something", "w") { |f| f.write("xyzxyz") }
      @first_repo.sync()
    }

    Dir.chdir(@second_client_dir) {
      File.open("something", "w") { |f| f.write("kkkkkk") }
      # this will result in a conflict when syncing
    }

    Dorkbox::sync_all_tracked()

    Dir.chdir(@third_client_dir) {
      File.open("something", "r") { |f| assert_equal("xyzxyz", f.read()) }
    }
  end

  def test_conflicted_client_doesnt_sync_until_fixed
    Dir.chdir(@first_client_dir) {
      File.open("something", "w") { |f| f.write("asd") }
      @first_repo.sync()
    }

    Dir.chdir(@second_client_dir) {
      File.open("something", "w") { |f| f.write("whatsup") }
      begin
        @second_repo.sync()
      rescue StandardError => e
      end

      assert(File.exists? Dorkbox::CONFLICT_STRING)

    }

    Dir.chdir(@second_client_dir) {
      begin
        @second_repo.sync()
        flunk('should have raised exception')
      rescue StandardError => e
      end
    }

    Dir.chdir(@second_client_dir) {
      `git merge dorkbox/master || true`
      File.open("something", "w") { |f| f.write("merged") }
      `git commit  -am 'merged'`
      File.delete(Dorkbox::CONFLICT_STRING)
      @second_repo.sync()
    }

    Dir.chdir(@first_client_dir) {
      @first_repo.sync()
      File.open("something") { |f| assert_equal("merged", f.read()) }
    }
  end

  def test_multiple_sync_without_changes_doesnt_crash
      @second_repo.sync()
      @second_repo.sync()
      @second_repo.sync()
  end

  def test_untracked_repository_doesnt_get_synced
    @second_repo.untrack()

    Dir.chdir(@first_client_dir) {
      File.open("something", "w") { |f| f.write("asd") }
      Dorkbox::sync_all_tracked()
    }

    Dir.chdir(@second_client_dir) {
      assert(!File.exists?("something"))

    }
  end


end


class TestCrontabAdding < MiniTest::Unit::TestCase
  include Dorkbox

  def setup
    begin
      @save_user_crontab = c('crontab -l 2>/dev/null')
    rescue
      @save_user_crontab = nil
    end
    `crontab -r || true`
  end

  def teardown
    if @save_user_crontab.nil?
      `crontab -r || true`
    else
      tmp = Tempfile.new('dorkbox-temp')
      tmp.puts(@save_user_crontab)
      tmp.flush()
      `crontab #{tmp.path}`
      tmp.close()
    end
  end

  def test_dorkbox_cron_is_enabled_when_crontab_empty
    Dorkbox::enable_dorkbox_cronjob()
    v = c('crontab -l')
    assert(v.scan(/#{DORKBOX_CRONTAB_COMMENT}/).size == 2)
  end

  def test_dorkbox_cron_is_not_duplicated_if_already_there
    Dorkbox::enable_dorkbox_cronjob()
    Dorkbox::enable_dorkbox_cronjob('asdasd')
    v = c('crontab -l')
    assert(v.scan(/#{DORKBOX_CRONTAB_COMMENT}/).size == 2)
  end

  def test_dorkbox_cron_is_updated_if_already_there
    Dorkbox::enable_dorkbox_cronjob()
    Dorkbox::enable_dorkbox_cronjob('asdasd')
    v = c('crontab -l')
    assert(v.scan(/#{DORKBOX_CRONTAB_COMMENT}/).size == 2)
    assert(v.scan(/asdasd/).size == 1)
  end
end
