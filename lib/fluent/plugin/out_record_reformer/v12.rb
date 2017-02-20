require_relative 'core'

module Fluent
  class RecordReformerOutput < Output
    Fluent::Plugin.register_output('record_reformer', self)

    include ::Fluent::RecordReformerOutputCore

    def initialize
      super
    end

    # To support log_level option implemented by Fluentd v0.10.43
    unless method_defined?(:log)
      define_method("log") { $log }
    end

    # Define `router` method of v0.12 to support v0.10 or earlier
    unless method_defined?(:router)
      define_method("router") { Fluent::Engine }
    end

    def configure(conf)
      super
    end

    def emit(tag, es, chain)
      process(tag, es)
      chain.next
    end
  end
end
