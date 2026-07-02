module SaferInitialize
  module ActiveRecord
    module Extensions
      extend ActiveSupport::Concern

      class_methods do
        def safer_initialize(filter = nil, message: 'initialize error', &block)
          after_initialize do |object|
            next if SaferInitialize::Globals.safe?

            check = -> { SaferInitialize::ActiveRecord::Extensions.run_check(object, filter, message, block) }
            if SaferInitialize::Globals.deferring?
              SaferInitialize::Globals.__deferred_checks << check
            else
              check.call
            end
          end
        end
      end

      def self.run_check(object, filter, message, block)
        result = filter ? object.send(filter) : object.instance_exec(object, &block)
        return if result

        message_text = message.respond_to?(:call) ? message.call(object) : message
        SaferInitialize.configuration.error_handle.call(SaferInitialize::Error.new(message_text))
      end
    end
  end
end
