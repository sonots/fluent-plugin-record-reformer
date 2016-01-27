require 'test/unit'
require 'fluent/log'
require 'fluent/test'

unless defined?(Test::Unit::AssertionFailedError)
  class Test::Unit::AssertionFailedError < StandardError
  end
end

# Reduce sleep period at
# https://github.com/fluent/fluentd/blob/a271b3ec76ab7cf89ebe4012aa5b3912333dbdb7/lib/fluent/test/base.rb#L81
module Fluent
  module Test
    class TestDriver
      def run(num_waits = 10, &block)
        @instance.start
        begin
          # wait until thread starts
          # num_waits.times { sleep 0.05 }
          sleep 0.05
          return yield
        ensure
          @instance.shutdown
        end
      end
    end
  end
end
