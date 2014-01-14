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
        conf.has_key?(k) # to suppress unread configuration warning
        @map[k] = v
      }
      # <record></record> directive
      conf.elements.select { |element| element.name == 'record' }.each { |element|
        element.each_pair { |k, v|
          element.has_key?(k) # to suppress unread configuration warning
          @map[k] = v
        }
      }

      @hostname = Socket.gethostname
    end

    def emit(tag, es, chain)
      tag_parts = tag.split('.')
      es.each { |time, record|
        t_time = Time.at(time)
        output_tag = expand_placeholder(@output_tag, record, tag, tag_parts, t_time)
        Engine.emit(output_tag, time, replace_record(record, tag, tag_parts, t_time))
      }
      chain.next
    rescue => e
      $log.warn "record_reformer: #{e.class} #{e.message} #{e.backtrace.join(', ')}"
    end

    private

    def replace_record(record, tag, tag_parts, time)
      @map.each_pair { |k, v|
        record[k] = expand_placeholder(v, record, tag, tag_parts, time)
      }
      record
    end

    # Replace placeholders in a string
    #
    # @param [String] str         the string to be replaced
    # @param [Hash]   record      the record, one of information
    # @param [String] tag         the tag
    # @param [Array]  tag_parts   the tag parts (tag splitted by .)
    # @param [Time]   time        the time
    def expand_placeholder(str, record, tag, tag_parts, time)
      struct = UndefOpenStruct.new(record)
      struct.tag  = tag
      struct.tags = struct.tag_parts = tag_parts # tags is for old version compatibility
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
