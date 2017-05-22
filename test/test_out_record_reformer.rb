require_relative 'helper'
require 'time'
require 'fluent/plugin/out_record_reformer'

Fluent::Test.setup

class RecordReformerOutputTest < Test::Unit::TestCase
  def feed(config, msgs: [''], syntax: :v1)
    d = create_driver(config, syntax: syntax, default_tag: @tag)
    d.run do
      records = msgs.map do |msg|
        next msg if msg.is_a?(Hash)
        { 'eventType0' => 'bar', 'message' => msg }
      end
      records.each do |record|
        d.feed(@time, record)
      end
    end

    @instance = d.instance
    d.events
  end

  setup do
    @hostname = Socket.gethostname.chomp
    @tag = 'test.tag'
    @tag_parts = @tag.split('.')
    @time = event_time("2010-05-04 03:02:01")
    Timecop.freeze(@time)
  end

  teardown do
    Timecop.return
  end

  CONFIG = %[
    tag reformed.${tag}

    hostname ${hostname}
    input_tag ${tag}
    time ${time.to_s}
    message ${hostname} ${tag_parts.last} ${URI.escape(message)}
  ]

  [:v1, :v0].each do |syntax|
    sub_test_case 'configure' do
      test 'typical usage' do
        assert_nothing_raised do
          create_driver(CONFIG, syntax: syntax)
        end
      end

      test "tag is not specified" do
        assert_raise(Fluent::ConfigError) do
          create_driver('', syntax: syntax)
        end
      end

      test "keep_keys must be specified together with renew_record true" do
        assert_raise(Fluent::ConfigError) do
          create_driver(%[keep_keys a], syntax: syntax)
        end
      end
    end

    sub_test_case "test options" do
      test 'typical usage' do
        msgs = ['1', '2']
        events = feed(CONFIG, syntax: syntax, msgs: msgs)
        assert_equal 2, events.size
        events.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal('bar', record['eventType0'])
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['input_tag'])
          assert_equal(Time.at(@time).localtime.to_s, record['time'])
          assert_equal("#{@hostname} #{@tag_parts[-1]} #{msgs[i]}", record['message'])
        end
      end

      test '(obsolete) output_tag' do
        config = %[output_tag reformed.${tag}]
        msgs = ['1']
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
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
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal('bar', record['eventType0'])
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['tag'])
          assert_equal(Time.at(@time).localtime.to_s, record['time'])
          assert_equal("#{@hostname} #{@tag_parts[-1]} #{msgs[i]}", record['message'])
        end
      end

      test 'remove_keys' do
        config = CONFIG + %[remove_keys eventType0,message]
        events = feed(config, syntax: syntax)
        events.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_not_include(record, 'eventType0')
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['input_tag'])
          assert_equal(Time.at(@time).localtime.to_s, record['time'])
          assert_not_include(record, 'message')
        end
      end

      test 'renew_record' do
        config = CONFIG + %[renew_record true]
        msgs = ['1', '2']
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_not_include(record, 'eventType0')
          assert_equal(@hostname, record['hostname'])
          assert_equal(@tag, record['input_tag'])
          assert_equal(Time.at(@time).localtime.to_s, record['time'])
          assert_equal("#{@hostname} #{@tag_parts[-1]} #{msgs[i]}", record['message'])
        end
      end

      test 'renew_time_key' do
        times = [ Time.at(event_time("2010-05-04 03:02:02")), Time.at(event_time("2010-05-04 03:02:03")) ]
        config = <<EOC
    tag reformed.${tag}
    enable_ruby true
    renew_time_key event_time_key
    <record>
      event_time_key ${Time.parse(record["message"]).to_i}
    </record>
EOC
        msgs = times.map{|t| t.to_s }
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal(times[i].to_i, time)
          assert_true(record.has_key?('event_time_key'))
        end
      end

      test 'renew_time_key and remove_keys' do
        config = <<EOC
    tag reformed.${tag}
    renew_time_key event_time_key
    remove_keys event_time_key
    auto_typecast true
    <record>
      event_time_key ${Time.parse(record["message"]).to_i}
    </record>
EOC
        times = [ Time.at(event_time("2010-05-04 03:02:02")), Time.at(event_time("2010-05-04 03:02:03")) ]
        msgs = times.map{|t| t.to_s }
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
          assert_equal("reformed.#{@tag}", tag)
          assert_equal(times[i].to_i, time)
          assert_false(record.has_key?('event_time_key'))
        end
      end

      test 'keep_keys' do
        config = %[tag reformed.${tag}\nrenew_record true\nkeep_keys eventType0,message]
        msgs = ['1', '2']
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
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
        events = feed(config, syntax: syntax, msgs: msgs)
        events.each_with_index do |(tag, time, record), i|
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
          events = feed(config, syntax: syntax)
          events.each do |(tag, time, record)|
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
          events = feed(config, syntax: syntax)
          events.each do |(tag, time, record)|
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
          events = feed(config, syntax: syntax)
          events.each do |(tag, time, record)|
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
          events = feed(config, syntax: syntax)
          events.each do |(tag, time, record)|
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
          events = feed(config, syntax: syntax)
          events.each do |(tag, time, record)|
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
          events = feed(config, syntax: syntax)
          events.each do |(tag, time, record)|
            assert_equal(Time.at(time).localtime.to_s, record['message'])
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
          events = feed(config, syntax: syntax, msgs: msgs)
          events.each_with_index do |(tag, time, record), i|
            assert_not_include(record, 'eventType0')
            assert_equal("bar", record['eventtype'])
            assert_equal("bar #{msgs[i]}", record['message'])
          end
        end

        test "Prevent overriting reserved keys (such as tag, etc) #40 with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            <record>
              new_tag ${tag}
              new_time ${time}
              new_record_tag ${record["tag"]}
              new_record_time ${record["time"]}
            </record>
          ]
          records = [{'tag' => 'tag', 'time' => 'time'}]
          events = feed(config, syntax: syntax, msgs: records)
          events.each do |(tag, time, record)|
            assert_not_equal('tag', record['new_tag'])
            assert_equal(@tag, record['new_tag'])
            assert_not_equal('time', record['new_time'])
            assert_equal(Time.at(@time).localtime.to_s, record['new_time'])
            assert_equal('tag', record['new_record_tag'])
            assert_equal('time', record['new_record_time'])
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
          es = feed(config, syntax: syntax, msgs: msgs)
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
          es = feed(config, syntax: syntax, msgs: msgs)
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
          es = feed(config, syntax: syntax, msgs: msgs)
          es.each_with_index do |(tag, time, record), i|
            assert_equal([{"tag" => @tag}], record['mixed_field'])
          end
        end

        if syntax == :v1
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
            es = feed(config, syntax: syntax, msgs: msgs)
            es.each_with_index do |(tag, time, record), i|
              assert_equal({@hostname=>'hostname',"foo.#{@tag}"=>'tag'}, record)
            end
          end
        end

        test "disabled autodetectction of value type with enable_ruby #{enable_ruby}" do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            auto_typecast false
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
          es = feed(config, syntax: syntax, msgs: msgs)
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
            auto_typecast true
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
          es = feed(config, syntax: syntax, msgs: msgs)
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

        test %Q[record["key"] with enable_ruby #{enable_ruby}] do
          config = %[
            tag tag
            enable_ruby #{enable_ruby}
            auto_typecast true
            <record>
              _timestamp ${record["@timestamp"]}
              _foo_bar   ${record["foo.bar"]}
            </record>
          ]
          d = create_driver(config, syntax: syntax)
          record = {
            "foo.bar"    => "foo.bar",
            "@timestamp" => 10,
          }
          es = feed(config, syntax: syntax, msgs: [record])
          es.each_with_index do |(tag, time, r), i|
            assert { r['_timestamp'] == record['@timestamp'] }
            assert { r['_foo_bar'] == record['foo.bar'] }
          end
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
        d = create_driver(config, syntax: syntax)
        mock(d.instance.log).warn("record_reformer: unknown placeholder `${unknown}` found")
        d.run { d.feed(@time, {}) }
        assert_equal 1, d.events.size
      end

      test 'failed to expand record field (enable_ruby yes)' do
        config = %[
          tag tag
          enable_ruby yes
          <record>
            message ${unknown['bar']}
          </record>
        ]
        d = create_driver(config, syntax: syntax)
        mock(d.instance.log).warn("record_reformer: failed to expand `%Q[\#{unknown['bar']}]`", anything)
        d.run { d.feed(@time, {}) }
        # feed, but nil value
        assert_equal 1, d.events.size
        d.events.each do |(tag, time, record)|
          assert_nil(record['message'])
        end
      end

      test 'failed to expand tag (enable_ruby yes)' do
        config = %[
          tag ${unknown['bar']}
          enable_ruby yes
        ]
        d = create_driver(config, syntax: syntax)
        mock(d.instance.log).warn("record_reformer: failed to expand `%Q[\#{unknown['bar']}]`", anything)
        d.run { d.feed(@time, {}) }
        # nil tag message should not be feedted
        assert_equal 0, d.events.size
      end

      test 'expand fields starting with @ (enable_ruby no)' do
        config = %[
          tag tag
          enable_ruby no
          <record>
            foo ${@timestamp}
          </record>
        ]
        d = create_driver(config, syntax: syntax)
        message = {"@timestamp" => "foo"}
        d.run { d.feed(@time, message) }
        d.events.each do |(tag, time, record)|
          assert_equal message["@timestamp"], record["foo"]
        end
      end

      # https://github.com/sonots/fluent-plugin-record-reformer/issues/35
      test 'auto_typecast placeholder containing {} (enable_ruby yes)' do
        config = %[
          tag tag
          enable_ruby yes
          auto_typecast yes
          <record>
            foo ${record.map{|k,v|v}}
          </record>
        ]
        d = create_driver(config, syntax: syntax)
        message = {"@timestamp" => "foo"}
        d.run { d.feed(@time, message) }
        d.events.each do |(tag, time, record)|
          assert_equal [message["@timestamp"]], record["foo"]
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
        d = create_driver(config, syntax: syntax)
        message = {"@timestamp" => "foo"}
        d.run { d.feed(@time, message) }
        d.events.each do |(tag, time, record)|
          assert_equal message["@timestamp"], record["foo"]
        end
      end
    end

    test "compatibility test (enable_ruby yes) (syntax: #{syntax})" do
      config = %[
        tag tag
        enable_ruby yes
        auto_typecast yes
        <record>
          _message   prefix-${message}-suffix
          _time      ${Time.at(time)}
          _number    ${number == '-' ? 0 : number}
          _match     ${/0x[0-9a-f]+/.match(hex)[0]}
          _timestamp ${__send__("@timestamp")}
          _foo_bar   ${__send__('foo.bar')}
        </record>
      ]
      d = create_driver(config, syntax: syntax)
      record = {
        "number"     => "-",
        "hex"        => "0x10",
        "foo.bar"    => "foo.bar",
        "@timestamp" => 10,
        "message"    => "10",
      }
      events = feed(config, syntax: syntax, msgs: [record])
      events.each_with_index do |(tag, time, r), i|
        assert { r['_message'] == "prefix-#{record['message']}-suffix" }
        assert { r['_time'] == Time.at(@time) }
        assert { r['_number'] == 0 }
        assert { r['_match'] == record['hex'] }
        assert { r['_timestamp'] == record['@timestamp'] }
        assert { r['_foo_bar'] == record['foo.bar'] }
      end
    end
  end
end
