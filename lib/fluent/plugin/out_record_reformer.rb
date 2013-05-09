require 'socket'

module Fluent
  class RecordReformerOutput < Output
    Fluent::Plugin.register_output('record_reformer', self)

    config_param :output_tag, :string

    BUILTIN_CONFIGURATIONS = %W(type output_tag)

    def configure(conf)
      super

      @map = {}
      conf.each_pair { |k, v|
        next if BUILTIN_CONFIGURATIONS.include?(k)
        conf.has_key?(k)
        @map[k] = v
      }

      @hostname = Socket.gethostname
    end

    def emit(tag, es, chain)
      tags = tag.split('.')
      es.each { |time, record|
        Engine.emit(@output_tag, time, expand_record(record, tag, tags, time))
      }
      chain.next
    rescue => e
      $log.warn e.message
      $log.warn e.backtrace.join(', ')
    end

    private

    def expand_record(record, tag, tags, time)
      time = Time.at(time)
      @map.each_pair { |k, v|
        record[k] = expand(v, record, tag, tags, time)
      }
      record
    end

    def expand(str, record, tag, tags, time)
      struct = OpenStruct.new(record)
      struct.tag  = tag
      struct.tags = tags
      struct.time = time
      struct.hostname = @hostname
      str = str.gsub(/\$\{([^}]+)\}/, '#{\1}') # ${..} => #{..}
      eval "\"#{str}\"", struct.instance_eval { binding }
    end
  end
end
