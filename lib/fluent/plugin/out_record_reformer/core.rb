require 'ostruct'
require 'socket'

module Fluent
  module RecordReformerOutputCore
    def initialize
      super
    end
    
    def self.included(klass)
      klass.config_param :output_tag, :string, :default => nil, # obsolete
        :desc => 'The output tag name. This option is deprecated. Use `tag` option instead.'
      klass.config_param :tag, :string, :default => nil,
        :desc => 'The output tag name.'
      klass.config_param :remove_keys, :string, :default => nil,
        :desc => 'Specify record keys to be removed by a string separated by , (comma).'
      klass.config_param :keep_keys, :string, :default => nil,
        :desc => 'Specify record keys to be kept by a string separated by , (comma).'
      klass.config_param :renew_record, :bool, :default => false,
        :desc => 'Creates an output record newly without extending (merging) the input record fields.'
      klass.config_param :renew_time_key, :string, :default => nil,
        :desc => 'Overwrites the time of events with a value of the record field.'
      klass.config_param :enable_ruby, :bool, :default => true, # true for lower version compatibility
        :desc => 'Enable to use ruby codes in placeholders.'
      klass.config_param :auto_typecast, :bool, :default => false, # false for lower version compatibility
        :desc => 'Automatically cast the field types.'
    end

    BUILTIN_CONFIGURATIONS = %W(@id @type @label type tag output_tag remove_keys renew_record keep_keys enable_ruby renew_time_key auto_typecast)

    def configure(conf)
      super

      map = {}
      conf.each_pair { |k, v|
        next if BUILTIN_CONFIGURATIONS.include?(k)
        conf.has_key?(k) # to suppress unread configuration warning
        map[k] = parse_value(v)
      }
      # <record></record> directive
      conf.elements.select { |element| element.name == 'record' }.each { |element|
        element.each_pair { |k, v|
          element.has_key?(k) # to suppress unread configuration warning
          map[k] = parse_value(v)
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

      placeholder_expander_params = {
        :log           => log,
        :auto_typecast => @auto_typecast,
      }
      @placeholder_expander =
        if @enable_ruby
          # require utilities which would be used in ruby placeholders
          require 'pathname'
          require 'uri'
          require 'cgi'
          RubyPlaceholderExpander.new(placeholder_expander_params)
        else
          PlaceholderExpander.new(placeholder_expander_params)
        end
      @map = @placeholder_expander.preprocess_map(map)
      @tag = @placeholder_expander.preprocess_map(@tag)

      @hostname = Socket.gethostname
    end

    def process(tag, es)
      tag_parts = tag.split('.')
      tag_prefix = tag_prefix(tag_parts)
      tag_suffix = tag_suffix(tag_parts)
      placeholder_values = {
        'tag'        => tag,
        'tags'       => tag_parts, # for old version compatibility
        'tag_parts'  => tag_parts,
        'tag_prefix' => tag_prefix,
        'tag_suffix' => tag_suffix,
        'hostname'   => @hostname,
      }
      last_record = nil
      es.each {|time, record|
        last_record = record # for debug log
        placeholder_values.merge!({
          'time'     => @placeholder_expander.time_value(time),
          'record'   => record,
        })
        new_tag, new_record = reform(@tag, record, placeholder_values)
        if new_tag
          if @renew_time_key && new_record.has_key?(@renew_time_key)
            time = new_record[@renew_time_key].to_i
          end
          @remove_keys.each {|k| new_record.delete(k) } if @remove_keys
          router.emit(new_tag, time, new_record)
        end
      }
    rescue => e
      log.warn "record_reformer: #{e.class} #{e.message} #{e.backtrace.first}"
      log.debug "record_reformer: tag:#{@tag} map:#{@map} record:#{last_record} placeholder_values:#{placeholder_values}"
    end

    private

    def parse_value(value_str)
      if value_str.start_with?('{', '[')
        JSON.parse(value_str)
      else
        value_str
      end
    rescue => e
      log.warn "failed to parse #{value_str} as json. Assuming #{value_str} is a string", :error_class => e.class, :error => e.message
      value_str # emit as string
    end

    def reform(tag, record, placeholder_values)
      placeholders = @placeholder_expander.prepare_placeholders(placeholder_values)

      new_tag = expand_placeholders(tag, placeholders)

      new_record = @renew_record ? {} : record.dup
      @keep_keys.each {|k| new_record[k] = record[k]} if @keep_keys and @renew_record
      new_record.merge!(expand_placeholders(@map, placeholders))

      [new_tag, new_record]
    end

    def expand_placeholders(value, placeholders)
      if value.is_a?(String)
        new_value = @placeholder_expander.expand(value, placeholders)
      elsif value.is_a?(Hash)
        new_value = {}
        value.each_pair do |k, v|
          new_key = @placeholder_expander.expand(k, placeholders, true)
          new_value[new_key] = expand_placeholders(v, placeholders)
        end
      elsif value.is_a?(Array)
        new_value = []
        value.each_with_index do |v, i|
          new_value[i] = expand_placeholders(v, placeholders)
        end
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

    # THIS CLASS MUST BE THREAD-SAFE
    class PlaceholderExpander
      attr_reader :placeholders, :log

      def initialize(params)
        @log = params[:log]
        @auto_typecast = params[:auto_typecast]
      end

      def time_value(time)
        Time.at(time).to_s
      end

      def preprocess_map(value, force_stringify = false)
        value
      end

      def prepare_placeholders(placeholder_values)
        placeholders = {}

        placeholder_values.each do |key, value|
          if value.kind_of?(Array) # tag_parts, etc
            size = value.size
            value.each_with_index do |v, idx|
              placeholders.store("${#{key}[#{idx}]}", v)
              placeholders.store("${#{key}[#{idx-size}]}", v) # support [-1]
            end
          elsif value.kind_of?(Hash) # record, etc
            value.each do |k, v|
              unless placeholder_values.has_key?(k) # prevent overwriting the reserved keys such as tag
                placeholders.store("${#{k}}", v)
              end
              placeholders.store(%Q[${#{key}["#{k}"]}], v) # record["foo"]
            end
          else # string, interger, float, and others?
            placeholders.store("${#{key}}", value)
          end
        end

        placeholders
      end

      # Expand string with placeholders
      #
      # @param [String] str
      # @param [Boolean] force_stringify the value must be string, used for hash key
      def expand(str, placeholders, force_stringify = false)
        if @auto_typecast and !force_stringify
          single_placeholder_matched = str.match(/\A(\${[^}]+}|__[A-Z_]+__)\z/)
          if single_placeholder_matched
            log_if_unknown_placeholder($1, placeholders)
            return placeholders[single_placeholder_matched[1]]
          end
        end
        str.gsub(/(\${[^}]+}|__[A-Z_]+__)/) {
          log_if_unknown_placeholder($1, placeholders)
          placeholders[$1]
        }
      end

      private

      def log_if_unknown_placeholder(placeholder, placeholders)
        unless placeholders.include?(placeholder)
          log.warn "record_reformer: unknown placeholder `#{placeholder}` found"
        end
      end
    end

    # THIS CLASS MUST BE THREAD-SAFE
    class RubyPlaceholderExpander
      attr_reader :log

      def initialize(params)
        @log = params[:log]
        @auto_typecast = params[:auto_typecast]
        @cleanroom_expander = CleanroomExpander.new
      end

      def time_value(time)
        Time.at(time)
      end

      # Preprocess record map to convert into ruby string expansion
      #
      # @param [Hash|String|Array] value record map config
      # @param [Boolean] force_stringify the value must be string, used for hash key
      def preprocess_map(value, force_stringify = false)
        new_value = nil
        if value.is_a?(String)
          if @auto_typecast and !force_stringify
            num_placeholders = value.scan('${').size
            if num_placeholders == 1 and value.start_with?('${') && value.end_with?('}')
              new_value = value[2..-2] # ${..} => ..
            end
          end
          unless new_value
            new_value = "%Q[#{value.gsub('${', '#{')}]" # xx${..}xx => %Q[xx#{..}xx]
          end
        elsif value.is_a?(Hash)
          new_value = {}
          value.each_pair do |k, v|
            new_value[preprocess_map(k, true)] = preprocess_map(v)
          end
        elsif value.is_a?(Array)
          new_value = []
          value.each_with_index do |v, i|
            new_value[i] = preprocess_map(v)
          end
        else
          new_value = value
        end
        new_value
      end

      def prepare_placeholders(placeholder_values)
        placeholder_values
      end

      # Expand string with placeholders
      #
      # @param [String] str
      def expand(str, placeholders, force_stringify = false)
        @cleanroom_expander.expand(
          str,
          placeholders['tag'],
          placeholders['time'],
          placeholders['record'],
          placeholders['tag_parts'],
          placeholders['tag_prefix'],
          placeholders['tag_suffix'],
          placeholders['hostname'],
        )
      rescue => e
        log.warn "record_reformer: failed to expand `#{str}`", :error_class => e.class, :error => e.message
        log.warn_backtrace
        nil
      end

      class CleanroomExpander
        def expand(__str_to_eval__, tag, time, record, tag_parts, tag_prefix, tag_suffix, hostname)
          tags = tag_parts # for old version compatibility
          Thread.current[:record_reformer_record] = record # for old version compatibility
          instance_eval(__str_to_eval__)
        end

        # for old version compatibility
        def method_missing(name)
          key = name.to_s
          record = Thread.current[:record_reformer_record]
          if record.has_key?(key)
            record[key]
          else
            raise NameError, "undefined local variable or method `#{key}'"
          end
        end

        (Object.instance_methods).each do |m|
          undef_method m unless m.to_s =~ /^__|respond_to_missing\?|object_id|public_methods|instance_eval|method_missing|define_singleton_method|respond_to\?|new_ostruct_member/
        end
      end
    end
  end
end
