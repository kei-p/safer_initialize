require 'safer_initialize/version'
require 'safer_initialize/globals'
require 'safer_initialize/configuration'
require 'safer_initialize/railtie'

module SaferInitialize
  class Error < StandardError; end

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  module_function

  def with_safe(&block)
    Globals.set(__safe: true, &block)
  end

  # Defer safer_initialize checks queued inside the block until the block
  # finishes, so associations preloaded by the enclosed queries are already
  # resolved by the time the checks run (avoids N+1). Globals must not be
  # mutated inside the block. On an exception the queue is discarded without
  # flushing. Cannot be nested.
  def defer
    raise Error, 'SaferInitialize.defer cannot be nested' if Globals.deferring?

    Globals.__deferring = true
    Globals.__deferred_checks = []

    result = yield

    checks = Globals.__deferred_checks
    Globals.__deferring = nil
    Globals.__deferred_checks = nil
    checks.each(&:call)
    result
  ensure
    Globals.__deferring = nil
    Globals.__deferred_checks = nil
  end
end
