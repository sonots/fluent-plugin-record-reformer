require 'socket'

module Fluent
  class RecordReformerOutput < Output
    Fluent::Plugin.register_output('record_reformer', self)

    def initialize
      super
      # require utilities for placeholder
      require 'pathname'
      require 'uri'
      require 'cgi'
    end

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
        t_time = Time.at(time)
        output_tag = expand_placeholder(@output_tag, record, tag, tags, t_time)
        Engine.emit(output_tag, time, replace_record(record, tag, tags, t_time))
      }
      chain.next
    rescue => e
      $log.warn e.message
      $log.warn e.backtrace.join(', ')
    end

    private

    def replace_record(record, tag, tags, time)
      @map.each_pair { |k, v|
        record[k] = expand_placeholder(v, record, tag, tags, time)
      }
      record
    end

    # Replace placeholders in a string
    #
    # @param [String] str    the string to be replaced
    # @param [Hash]   record the record, one of information
    # @param [String] tag    one of information
    # @param [Array]  tags   one of information
    # @param [Time]   time   one of information
    def expand_placeholder(str, record, tag, tags, time)
      struct = UndefOpenStruct.new(record)
      struct.tag  = tag
      struct.tags = tags
      struct.time = time
      struct.hostname = @hostname
      str = str.gsub(/\$\{([^}]+)\}/, '#{\1}') # ${..} => #{..}
      eval "\"#{str}\"", struct.instance_eval { binding }
    end

    class UndefOpenStruct < OpenStruct
      (Object.instance_methods).each do |m|
        undef_method m unless m.to_s =~ /^__|respond_to_missing\?|object_id|public_methods|instance_eval|method_missing|define_singleton_method|respond_to\?|new_ostruct_member/
      end
    end
  end
end
