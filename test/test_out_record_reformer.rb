require_relative 'helper'
require 'rr'
require 'time'
require 'timecop'
require 'fluent/plugin/out_record_reformer'

Fluent::Test.setup

class RecordReformerOutputTest < Test::Unit::TestCase
  setup do
    @hostname = Socket.gethostname.chomp
    @tag = 'test.tag'
    @tag_parts = @tag.split('.')
    @time = Time.local(1,2,3,4,5,2010,nil,nil,nil,nil)
    Timecop.freeze(@time)
  end

  teardown do
    Timecop.return
  end

  def create_driver(conf, use_v1)
    Fluent::Test::OutputTestDriver.new(Fluent::RecordReformerOutput, @tag).configure(conf, use_v1)
  end

  def emit(config, use_v1, msgs = [''])
    d = create_driver(config, use_v1)
    d.run do
      msgs.each do |msg|
        record = {
          'eventType0' => 'bar',
          'message'    => msg,
        }
        record = record.merge(msg) if msg.is_a?(Hash)
        d.emit(record, @time)
      end
    end

    @instance = d.instance
    d.emits
  end

  CONFIG = %[
    tag reformed.${tag}

    hostname ${hostname}
    input_tag ${tag}
    time ${time.to_s}
    message ${hostname} ${tag_parts.last} ${URI.escape(message)}
  ]

  [true, false].each do |use_v1|
    sub_test_case 'configure' do
      test 'typical usage' do
        assert_nothing_raised do
          create_driver(CONFIG, use_v1)
        end
      end

      test "tag is not specified" do
        assert_raise(Fluent::ConfigError) do
          create_driver('', use_v1)
        end
      end

      test "keep_keys must be specified together with renew_record true" do
        assert_raise(Fluent::ConfigError) do
          create_driver(%[keep_keys a], use_v1)
        end
      end
    end

    sub_test_case "test options" do
      test 'typical usage' do
        msgs = ['1', '2']
        emits = emit(CONFIG, use_v1, msgs)
        assert_equal 2, emits.size
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal('bar', record['eventType0'])
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['input_tag'])
          assert_equal(@time.to_s, record['time'])
          assert_equal("#{@hostname} #{@tag_parts[-1]} #{msgs[i]}", record['message'])
        end
      end

      test '(obsolete) output_tag' do
        config = %[output_tag reformed.${tag}]
        msgs = ['1']
        emits = emit(config, use_v1, msgs)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
        end
      end

      test 'record directive' do
        config = %[
        tag reformed.${tag}

        <record>
          hostname ${hostname}
          tag ${tag}
          time ${time.to_s}
          message ${hostname} ${tag_parts.last} ${message}
        </record>
        ]
        msgs = ['1', '2']
        emits = emit(config, use_v1, msgs)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal('bar', record['eventType0'])
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['tag'])
          assert_equal(@time.to_s, record['time'])
          assert_equal("#{@hostname} #{@tag_parts[-1]} #{msgs[i]}", record['message'])
        end
      end

      test 'remove_keys' do
        config = CONFIG + %[remove_keys eventType0,message]
        emits = emit(config, use_v1)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_not_include(record, 'eventType0')
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['input_tag'])
          assert_equal(@time.to_s, record['time'])
          assert_not_include(record, 'message')
        end
      end

      test 'renew_record' do
        config = CONFIG + %[renew_record true]
        msgs = ['1', '2']
        emits = emit(config, use_v1, msgs)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_not_include(record, 'eventType0')
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['input_tag'])
          assert_equal(@time.to_s, record['time'])
          assert_equal("#{@hostname} #{@tag_parts[-1]} #{msgs[i]}", record['message'])
        end
      end

      test 'renew_time_key' do
        times = [ Time.local(2,2,3,4,5,2010,nil,nil,nil,nil), Time.local(3,2,3,4,5,2010,nil,nil,nil,nil) ]
        config = <<EOC
    tag reformed.${tag}
    enable_ruby true
    message ${Time.parse(message).to_i}
    renew_time_key message
EOC
        msgs = times.map{|t| t.to_s }
        emits = emit(config, use_v1, msgs)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal(times[i].to_i, time)
        end
      end

      test 'keep_keys' do
        config = %[tag reformed.${tag}\nrenew_record true\nkeep_keys eventType0,message]
        msgs = ['1', '2']
        emits = emit(config, use_v1, msgs)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal('bar', record['eventType0'])
          assert_equal(msgs[i], record['message'])
        end
      end

      test 'enable_ruby no' do
        config = %[
          tag reformed.${tag}
          enable_ruby no
          <record>
            message ${hostname} ${tag_parts.last} ${URI.encode(message)}
          </record>
        ]
        msgs = ['1', '2']
        emits = emit(config, use_v1, msgs)
        emits.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal("#{@hostname}  ", record['message'])
        end
      end
    end

    sub_test_case 'test placeholders' do
      %w[yes no].each do |enable_ruby|

        test "hostname with enble_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              message ${hostname}
            </record>
          ]
          emits = emit(config, use_v1)
          emits.each do |(tag, time, record)|
            assert_equal(@hostname, record['message'])
          end
        end

        test "tag with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              message ${tag}
            </record>
          ]
          emits = emit(config, use_v1)
          emits.each do |(tag, time, record)|
            assert_equal(@tag, record['message'])
          end
        end

        test "tag_parts with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              message ${tag_parts[0]} ${tag_parts[-1]}
            </record>
          ]
          expected = "#{@tag.split('.').first} #{@tag.split('.').last}"
          emits = emit(config, use_v1)
          emits.each do |(tag, time, record)|
            assert_equal(expected, record['message'])
          end
        end

        test "(obsolete) tags with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              message ${tags[0]} ${tags[-1]}
            </record>
          ]
          expected = "#{@tag.split('.').first} #{@tag.split('.').last}"
          emits = emit(config, use_v1)
          emits.each do |(tag, time, record)|
            assert_equal(expected, record['message'])
          end
        end

        test "${tag_prefix[N]} and ${tag_suffix[N]} with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              message ${tag_prefix[1]} ${tag_prefix[-2]} ${tag_suffix[2]} ${tag_suffix[-3]}
            </record>
          ]
          @tag = 'prefix.test.tag.suffix'
          expected = "prefix.test prefix.test.tag tag.suffix test.tag.suffix"
          emits = emit(config, use_v1)
          emits.each do |(tag, time, record)|
            assert_equal(expected, record['message'])
          end
        end

        test "time with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              message ${time}
            </record>
          ]
          emits = emit(config, use_v1)
          emits.each do |(tag, time, record)|
            assert_equal(@time.to_s, record['message'])
          end
        end

        test "record keys with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            remove_keys eventType0
            <record>
              message bar ${message}
              eventtype ${eventType0}
            </record>
          ]
          msgs = ['1', '2']
          emits = emit(config, use_v1, msgs)
          emits.each_with_index do |(tag, time, record), i|
            assert_not_include(record, 'eventType0')
            assert_equal("bar", record['eventtype'])
            assert_equal("bar #{msgs[i]}", record['message'])
          end
        end

        test "hash values with placeholders with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              hash_field {"hostname":"${hostname}", "tag":"${tag}", "${tag}":100}
            </record>
          ]
          msgs = ['1', '2']
          es = emit(config, use_v1, msgs)
          es.each_with_index do |(tag, time, record), i|
            assert_equal({"hostname" => @hostname, "tag" => @tag, "#{@tag}" => 100}, record['hash_field'])
          end
        end

        test "array values with placeholders with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              array_field ["${hostname}", "${tag}"]
            </record>
          ]
          msgs = ['1', '2']
          es = emit(config, use_v1, msgs)
          es.each_with_index do |(tag, time, record), i|
            assert_equal([@hostname, @tag], record['array_field'])
          end
        end

        test "array and hash values with placeholders with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              mixed_field [{"tag":"${tag}"}]
            </record>
          ]
          msgs = ['1', '2']
          es = emit(config, use_v1, msgs)
          es.each_with_index do |(tag, time, record), i|
            assert_equal([{"tag" => @tag}], record['mixed_field'])
          end
        end

        if use_v1 == true
          # works with only v1 config
          test "keys with placeholders with enable_ruby #{enable_ruby}" do
            config = %[
              tag tag
              enable_ruby #{enable_ruby}
              renew_record true
              <record>
                ${hostname} hostname
                foo.${tag} tag
              </record>
            ]
            msgs = ['1', '2']
            es = emit(config, use_v1, msgs)
            es.each_with_index do |(tag, time, record), i|
              assert_equal({@hostname=>'hostname',"foo.#{@tag}"=>'tag'}, record)
            end
          end
        end

        test "disabled autodetectction of value type with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            autodetect_value_type false
            <record>
              single      ${source}
              multiple    ${source}${source}
              with_prefix prefix-${source}
              with_suffix ${source}-suffix
            </record>
          ]
          msgs = [
            { "source" => "string" },
            { "source" => 123 },
            { "source" => [1, 2] },
            { "source" => {a:1, b:2} },
            { "source" => nil },
          ]
          expected_results = [
            { :single      => "string",
              :multiple    => "stringstring",
              :with_prefix => "prefix-string",
              :with_suffix => "string-suffix" },
            { :single      => 123.to_s,
              :multiple    => "#{123.to_s}#{123.to_s}",
              :with_prefix => "prefix-#{123.to_s}",
              :with_suffix => "#{123.to_s}-suffix" },
            { :single      => [1, 2].to_s,
              :multiple    => "#{[1, 2].to_s}#{[1, 2].to_s}",
              :with_prefix => "prefix-#{[1, 2].to_s}",
              :with_suffix => "#{[1, 2].to_s}-suffix" },
            { :single      => {a:1, b:2}.to_s,
              :multiple    => "#{{a:1, b:2}.to_s}#{{a:1, b:2}.to_s}",
              :with_prefix => "prefix-#{{a:1, b:2}.to_s}",
              :with_suffix => "#{{a:1, b:2}.to_s}-suffix" },
            { :single      => nil.to_s,
              :multiple    => "#{nil.to_s}#{nil.to_s}",
              :with_prefix => "prefix-#{nil.to_s}",
              :with_suffix => "#{nil.to_s}-suffix" },
          ]
          actual_results = []
          es = emit(config, use_v1, msgs)
          es.each_with_index do |(tag, time, record), i|
            actual_results << {
              :single      => record["single"],
              :multiple    => record["multiple"],
              :with_prefix => record["with_prefix"],
              :with_suffix => record["with_suffix"],
            }
          end
          assert_equal(expected_results, actual_results)
        end

        test "enabled autodetectction of value type with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            autodetect_value_type true
            <record>
              single      ${source}
              multiple    ${source}${source}
              with_prefix prefix-${source}
              with_suffix ${source}-suffix
            </record>
          ]
          msgs = [
            { "source" => "string" },
            { "source" => 123 },
            { "source" => [1, 2] },
            { "source" => {a:1, b:2} },
            { "source" => nil },
          ]
          expected_results = [
            { :single      => "string",
              :multiple    => "stringstring",
              :with_prefix => "prefix-string",
              :with_suffix => "string-suffix" },
            { :single      => 123,
              :multiple    => "#{123.to_s}#{123.to_s}",
              :with_prefix => "prefix-#{123.to_s}",
              :with_suffix => "#{123.to_s}-suffix" },
            { :single      => [1, 2],
              :multiple    => "#{[1, 2].to_s}#{[1, 2].to_s}",
              :with_prefix => "prefix-#{[1, 2].to_s}",
              :with_suffix => "#{[1, 2].to_s}-suffix" },
            { :single      => {a:1, b:2},
              :multiple    => "#{{a:1, b:2}.to_s}#{{a:1, b:2}.to_s}",
              :with_prefix => "prefix-#{{a:1, b:2}.to_s}",
              :with_suffix => "#{{a:1, b:2}.to_s}-suffix" },
            { :single      => nil,
              :multiple    => "#{nil.to_s}#{nil.to_s}",
              :with_prefix => "prefix-#{nil.to_s}",
              :with_suffix => "#{nil.to_s}-suffix" },
          ]
          actual_results = []
          es = emit(config, use_v1, msgs)
          es.each_with_index do |(tag, time, record), i|
            actual_results << {
              :single      => record["single"],
              :multiple    => record["multiple"],
              :with_prefix => record["with_prefix"],
              :with_suffix => record["with_suffix"],
            }
          end
          assert_equal(expected_results, actual_results)
        end
      end

      test 'unknown placeholder (enable_ruby no)' do
        config = %[
          tag tag
          enable_ruby no
          <record>
            message ${unknown}
          </record>
        ]
        d = create_driver(config, use_v1)
        mock(d.instance.log).warn("record_reformer: unknown placeholder `${unknown}` found")
        d.run { d.emit({}, @time) }
        assert_equal 1, d.emits.size
      end

      test 'failed to expand record field (enable_ruby yes)' do
        config = %[
          tag tag
          enable_ruby yes
          <record>
            message ${unknown['bar']}
          </record>
        ]
        d = create_driver(config, use_v1)
        mock(d.instance.log).warn("record_reformer: failed to expand `${unknown['bar']}`", anything)
        d.run { d.emit({}, @time) }
        # emit, but nil value
        assert_equal 1, d.emits.size
        d.emits.each do |(tag, time, record)|
          assert_nil(record['message'])
        end
      end

      test 'failed to expand tag (enable_ruby yes)' do
        config = %[
          tag ${unknown['bar']}
          enable_ruby yes
        ]
        d = create_driver(config, use_v1)
        mock(d.instance.log).warn("record_reformer: failed to expand `${unknown['bar']}`", anything)
        d.run { d.emit({}, @time) }
        # nil tag message should not be emitted
        assert_equal 0, d.emits.size
      end

      test 'expand fields starting with @ (enable_ruby no)' do
        config = %[
          tag tag
          enable_ruby no
          <record>
            foo ${@timestamp}
          </record>
        ]
        d = create_driver(config, use_v1)
        message = {"@timestamp" => "foo"}
        d.run { d.emit(message, @time) }
        d.emits.each do |(tag, time, record)|
          assert_equal message["@timestamp"], record["foo"]
        end
      end

      test 'expand fields starting with @ (enable_ruby yes)' do
        config = %[
          tag tag
          enable_ruby yes
          <record>
            foo ${__send__("@timestamp")}
          </record>
        ]
        d = create_driver(config, use_v1)
        message = {"@timestamp" => "foo"}
        d.run { d.emit(message, @time) }
        d.emits.each do |(tag, time, record)|
          assert_equal message["@timestamp"], record["foo"]
        end
      end
    end
  end
end
