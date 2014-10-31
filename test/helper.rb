require 'test/unit'
require 'fluent/log'
require 'fluent/test'

unless defined?(Test::Unit::AssertionFailedError)
  class Test::Unit::AssertionFailedError < StandardError
  end
end

# Stop non required sleep at
# https://github.com/fluent/fluentd/blob/018791f6b1b0400b71e37df2fb3ad80e456d2c11/lib/fluent/test/base.rb#L56
module Fluent
  module Test
    class TestDriver
      def run(&block)
        @instance.start
        begin
          # wait until thread starts
          # 10.times { sleep 0.05 }
          return yield
        ensure
          @instance.shutdown
        end
      end
    end
  end
end
