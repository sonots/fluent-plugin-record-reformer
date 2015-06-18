require 'ostruct'

module Fluent
  class RecordReformerOutput < Output
    Fluent::Plugin.register_output('record_reformer', self)

    def initialize
      require 'socket'
      super
    end

    config_param :output_tag, :string, :default => nil # obsolete
    config_param :tag, :string, :default => nil
    config_param :remove_keys, :string, :default => nil
    config_param :keep_keys, :string, :default => nil
    config_param :renew_record, :bool, :default => false
    config_param :renew_time_key, :string, :default => nil
    config_param :enable_ruby, :bool, :default => true # true for lower version compatibility

    BUILTIN_CONFIGURATIONS = %W(type tag output_tag remove_keys renew_record keep_keys enable_ruby renew_time_key)

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

      @map = {}
      conf.each_pair { |k, v|
        next if BUILTIN_CONFIGURATIONS.include?(k)
        conf.has_key?(k) # to suppress unread configuration warning
        @map[k] = parse_value(v)
      }
      # <record></record> directive
      conf.elements.select { |element| element.name == 'record' }.each { |element|
        element.each_pair { |k, v|
          element.has_key?(k) # to suppress unread configuration warning
          @map[k] = parse_value(v)
        }
      }

      if @remove_keys
        @remove_keys = @remove_keys.split(',')
      end

      if @keep_keys
        raise Fluent::ConfigError, "out_record_reformer: `renew_record` must be true to use `keep_keys`" unless @renew_record
        @keep_keys = @keep_keys.split(',')
      end

      if @output_tag and @tag.nil? # for lower version compatibility
        log.warn "out_record_reformer: `output_tag` is deprecated. Use `tag` option instead."
        @tag = @output_tag
      end
      if @tag.nil?
        raise Fluent::ConfigError, "out_record_reformer: `tag` must be specified"
      end

      @placeholder_expander =
        if @enable_ruby
          # require utilities which would be used in ruby placeholders
          require 'pathname'
          require 'uri'
          require 'cgi'
          RubyPlaceholderExpander.new(log)
        else
          PlaceholderExpander.new(log)
        end

      @hostname = Socket.gethostname
    end

    def emit(tag, es, chain)
      tag_parts = tag.split('.')
      tag_prefix = tag_prefix(tag_parts)
      tag_suffix = tag_suffix(tag_parts)
      placeholders = {
        'tag' => tag,
        'tags' => tag_parts,
        'tag_parts' => tag_parts,
        'tag_prefix' => tag_prefix,
        'tag_suffix' => tag_suffix,
        'hostname' => @hostname,
      }
      last_record = nil
      es.each {|time, record|
        last_record = record # for debug log
        new_tag, new_record = reform(@tag, time, record, placeholders)
        if new_tag
          if @renew_time_key && new_record.has_key?(@renew_time_key)
            time = new_record[@renew_time_key].to_i
          end
          router.emit(new_tag, time, new_record)
        end
      }
      chain.next
    rescue => e
      log.warn "record_reformer: #{e.class} #{e.message} #{e.backtrace.first}"
      log.debug "record_reformer: tag:#{@tag} map:#{@map} record:#{last_record} placeholders:#{placeholders}"
    end

    private

    def parse_value(value_str)
      if value_str.start_with?('{', '[')
        JSON.parse(value_str)
      else
        matched = value_str.match(/\A(\$\{[^}]+\})\s*([-+])\s*(\[.*\])\z/)
        if matched
          field    = matched[1]
          operator = matched[2]
          values   = matched[3]
          ArrayReformer.new(field, operator, JSON.parse(values))
        else
        value_str
        end
      end
    rescue => e
      log.warn "failed to parse #{value_str} as json. Assuming #{value_str} is a string", :error_class => e.class, :error => e.message
      value_str # emit as string
    end

    def reform(tag, time, record, opts)
      @placeholder_expander.prepare_placeholders(time, record, opts)
      new_tag = @placeholder_expander.expand(tag)

      new_record = @renew_record ? {} : record.dup
      @keep_keys.each {|k| new_record[k] = record[k]} if @keep_keys and @renew_record
      new_record.merge!(expand_placeholders(@map))
      @remove_keys.each {|k| new_record.delete(k) } if @remove_keys

      [new_tag, new_record]
    end

    def expand_placeholders(value)
      if value.is_a?(String)
        new_value = @placeholder_expander.expand(value)
      elsif value.is_a?(Hash)
        new_value = {}
        value.each_pair do |k, v|
          new_value[@placeholder_expander.expand(k)] = expand_placeholders(v)
        end
      elsif value.is_a?(Array)
        new_value = []
        value.each_with_index do |v, i|
          new_value[i] = expand_placeholders(v)
        end
      elsif value.is_a?(ArrayReformer)
        expanded_values = value.values.map do |v|
          expand_placeholders(v)
        end
        new_value = @placeholder_expander.expand_array(value, expanded_values)
      else
        new_value = value
      end
      new_value
    end

    def tag_prefix(tag_parts)
      return [] if tag_parts.empty?
      tag_prefix = [tag_parts.first]
      1.upto(tag_parts.size-1).each do |i|
        tag_prefix[i] = "#{tag_prefix[i-1]}.#{tag_parts[i]}"
      end
      tag_prefix
    end

    def tag_suffix(tag_parts)
      return [] if tag_parts.empty?
      rev_tag_parts = tag_parts.reverse
      rev_tag_suffix = [rev_tag_parts.first]
      1.upto(tag_parts.size-1).each do |i|
        rev_tag_suffix[i] = "#{rev_tag_parts[i]}.#{rev_tag_suffix[i-1]}"
      end
      rev_tag_suffix.reverse!
    end

    class ArrayReformer
      attr_reader :source_field, :operator, :values

      SUPPORTED_OPERATORS = ["+", "-"]

      def initialize(source_field, operator, values)
        @source_field = source_field
        @operator     = operator
        @values       = values
        validate
      end

      def apply(base, values)
        base = [base] unless base.is_a?(Array)
        case @operator
        when "+"
          base + values
        when "-"
          base - values
        end
      end

      private
      def validate
        unless SUPPORTED_OPERATORS.include?(@operator)
          raise Fluent::ConfigError, "out_record_reformer: unknown operator: #{@operator}"
        end
        unless @values.is_a?(Array)
          raise Fluent::ConfigError, "out_record_reformer: invalid array: #{@values}"
        end
      end
    end

    class PlaceholderExpander
      attr_reader :placeholders, :log

      def initialize(log)
        @log = log
      end

      def prepare_placeholders(time, record, opts)
        placeholders = { '${time}' => Time.at(time).to_s }
        record.each {|key, value| placeholders.store("${#{key}}", value) }

        opts.each do |key, value|
          if value.kind_of?(Array) # tag_parts, etc
            size = value.size
            value.each_with_index { |v, idx|
              placeholders.store("${#{key}[#{idx}]}", v)
              placeholders.store("${#{key}[#{idx-size}]}", v) # support [-1]
            }
          else # string, interger, float, and others?
            placeholders.store("${#{key}}", value)
          end
        end

        @placeholders = placeholders
      end

      def expand(str)
        str.gsub(/(\${[^}]+}|__[A-Z_]+__)/) {
          log.warn "record_reformer: unknown placeholder `#{$1}` found" unless @placeholders.include?($1)
          @placeholders[$1]
        }
      end

      def expand_array(reformer, values)
        base = @placeholders[reformer.source_field] || []
        reformer.apply(base, values)
      end
    end

    class RubyPlaceholderExpander
      attr_reader :placeholders, :log

      def initialize(log)
        @log = log
      end

      # Get placeholders as a struct
      #
      # @param [Time]   time        the time
      # @param [Hash]   record      the record
      # @param [Hash]   opts        others
      def prepare_placeholders(time, record, opts)
        struct = UndefOpenStruct.new(record)
        struct.time = Time.at(time)
        opts.each {|key, value| struct.__send__("#{key}=", value) }
        @placeholders = struct
      end

      # Replace placeholders in a string
      #
      # @param [String] str         the string to be replaced
      def expand(str)
        interpolated = str.gsub(/\$\{([^}]+)\}/, '#{\1}') # ${..} => #{..}
        eval "\"#{interpolated}\"", @placeholders.instance_eval { binding }
      rescue => e
        log.warn "record_reformer: failed to expand `#{str}`", :error_class => e.class, :error => e.message
        log.warn_backtrace
        nil
      end

      def expand_array(reformer, values)
        base = expand(reformer.source_field)
        begin
          base = JSON.parse(base)
        rescue JSON::ParserError
        end
        base ||= []
        reformer.apply(base, values)
      end

      class UndefOpenStruct < OpenStruct
        (Object.instance_methods).each do |m|
          undef_method m unless m.to_s =~ /^__|respond_to_missing\?|object_id|public_methods|instance_eval|method_missing|define_singleton_method|respond_to\?|new_ostruct_member/
        end
      end
    end
  end
end
