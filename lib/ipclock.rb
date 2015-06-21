require 'preconditions'

module Dorkbox
  class IPCLock
    class AlreadyLockedException < StandardError

    end

    def initialize(lock_path)
      @lock_path = lock_path
    end

    def exclusive(options={}, &block)
      Preconditions.check_not_nil(block, "block is mandatory")
      lockfile = File.open(@lock_path, File::RDWR, 0644)
      can_lock = lockfile.flock(File::LOCK_EX|File::LOCK_NB)
      if (can_lock.eql?(false))
        raise Gpubruteforcerd::Lock::AlreadyLockedException.new(options.fetch(:message, 'lock already acquired'))
      end
      begin
        block.call()
      ensure
        lockfile.flock(File::LOCK_UN)
        lockfile.close()
      end
    end
  end
end
