require_relative 'core'

module Fluent
  class Plugin::RecordReformerOutput < Plugin::Output
    Fluent::Plugin.register_output('record_reformer', self)

    helpers :event_emitter
    include ::Fluent::RecordReformerOutputCore

    def initialize
      super
    end
    
    def configure(conf)
      super
    end

    def multi_workers_ready?
      true
    end

    def process(tag, es)
      super
    end
  end
end
