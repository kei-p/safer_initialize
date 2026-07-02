require 'active_support'

module SaferInitialize
  class Globals < ActiveSupport::CurrentAttributes
    attribute :__safe, :__deferring, :__deferred_checks

    def safe?
      !!__safe
    end

    def deferring?
      !!__deferring
    end
  end
end
