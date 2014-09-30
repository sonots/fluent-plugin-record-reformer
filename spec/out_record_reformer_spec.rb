# encoding: UTF-8
require_relative 'spec_helper'

describe Fluent::RecordReformerOutput do
  before { Fluent::Test.setup }
  CONFIG = %[
    tag reformed.${tag}

    hostname ${hostname}
    input_tag ${tag}
    time ${time.strftime('%S')}
    message ${hostname} ${tag_parts.last} ${URI.escape(message)}
  ]
  let(:tag) { 'test.tag' }
  let(:tag_parts) { tag.split('.') }
  let(:hostname) { Socket.gethostname.chomp }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::RecordReformerOutput, tag).configure(config) }

  describe 'test configure' do
    describe 'good configuration' do
      subject { driver.instance }

      context "check default" do
        let(:config) { CONFIG }
        it { expect { subject }.not_to raise_error }
      end

      context "tag is not specified" do
        let(:config) { %[] }
        it { expect { subject }.to raise_error(Fluent::ConfigError) }
      end

      context "keep_keys must be specified togerther with renew_record true" do
        let(:config) { %[keep_keys a] }
        it { expect { subject }.to raise_error(Fluent::ConfigError) }
      end
    end
  end

  describe 'test emit' do
    let(:time) { Time.now }
    let(:emit) do
      driver.run { driver.emit({'foo'=>'bar', 'message' => '1'}, time.to_i) }
    end

    context 'typical usage' do
      let(:emit) do
        driver.run do
          driver.emit({'foo'=>'bar', 'message' => '1'}, time.to_i)
          driver.emit({'foo'=>'bar', 'message' => '2'}, time.to_i)
        end
      end
      let(:config) { CONFIG }
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'hostname' => hostname,
          'input_tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 1",
        })
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'hostname' => hostname,
          'input_tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 2",
        })
      end
      it { emit }
    end

    context 'obsolete output_tag' do
      let(:config) {%[
        output_tag reformed.${tag}
      ]}
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'message' => "1",
        })
      end
      it { emit }
    end

    context 'record directive' do
      let(:config) {%[
        tag reformed.${tag}

        <record>
          hostname ${hostname}
          tag ${tag}
          time ${time.strftime('%S')}
          message ${hostname} ${tag_parts.last} ${message}
        </record>
      ]}
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'hostname' => hostname,
          'tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 1",
        })
      end
      it { emit }
    end

    context 'remove_keys' do
      let(:config) { CONFIG + %[remove_keys foo,message] }
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'hostname' => hostname,
          'input_tag' => tag,
          'time' => time.strftime('%S'),
        })
      end
      it { emit }
    end

    context 'renew_record true' do
      let(:config) { CONFIG + %[renew_record true] }
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'hostname' => hostname,
          'input_tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 1",
        })
      end
      it { emit }
    end

    context 'keep_keys' do
      let(:emit) do
        driver.run { driver.emit({'foo'=>'bar', 'message' => 1}, time.to_i) }
      end
      let(:config) { %[tag reformed.${tag}\nrenew_record true\nkeep_keys foo,message] }
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'message' => 1, # this keep type
        })
      end
      it { emit }
    end

    context 'unknown placeholder (enable_ruby no)' do
      let(:emit) do
        driver.run { driver.emit({}, time.to_i) }
      end
      let(:config) {%[
        tag reformed.${tag}
        enable_ruby no
        message ${unknown}
      ]}
      before do
        driver.instance.log.should_receive(:warn).with("record_reformer: unknown placeholder `${unknown}` found")
      end
      it { emit }
    end
  end

  describe 'test placeholders' do
    let(:time) { Time.now }
    let(:emit) do
      driver.run { driver.emit({}, time.to_i) }
    end

    %w[yes no].each do |enable_ruby|
      context "hostname with enble_ruby #{enable_ruby}" do
        let(:config) {%[
          tag tag
          enable_ruby #{enable_ruby}
          message ${hostname}
        ]}
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, {'message' => hostname})
        end
        it { emit }
      end

      context "tag with enable_ruby #{enable_ruby}" do
        let(:config) {%[
          tag tag
          enable_ruby #{enable_ruby}
          message ${tag}
        ]}
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, {'message' => tag})
        end
        it { emit }
      end

      context "tag_parts with enable_ruby #{enable_ruby}" do
        let(:config) {%[
          tag tag
          enable_ruby #{enable_ruby}
          message ${tag_parts[0]} ${tag_parts[-1]}
        ]}
        let(:expected) { "#{tag.split('.').first} #{tag.split('.').last}" }
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, {'message' => expected})
        end
        it { emit }
      end

      context "support old tags with enable_ruby #{enable_ruby}" do
        let(:config) {%[
          tag tag
          enable_ruby #{enable_ruby}
          message ${tags[0]} ${tags[-1]}
        ]}
        let(:expected) { "#{tag.split('.').first} #{tag.split('.').last}" }
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, {'message' => expected})
        end
        it { emit }
      end

      context "${tag_prefix[N]} and ${tag_suffix[N]} with enable_ruby #{enable_ruby}" do
        let(:config) {%[
          tag ${tag_suffix[-2]}
          enable_ruby #{enable_ruby}
          message ${tag_prefix[1]} ${tag_prefix[-2]} ${tag_suffix[2]} ${tag_suffix[-3]}
        ]}
        let(:tag) { 'prefix.test.tag.suffix' }
        let(:expected) { "prefix.test prefix.test.tag tag.suffix test.tag.suffix" }
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag.suffix", time.to_i, { 'message' => "prefix.test prefix.test.tag tag.suffix test.tag.suffix" })
        end
        it { emit }
      end

      context "time with enable_ruby #{enable_ruby}" do
        let(:config) {%[
          tag tag
          enable_ruby #{enable_ruby}
          time ${time}
        ]}
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, {'time' => time.to_s})
        end
        it { emit }
      end

      context "record with enable_ruby #{enable_ruby}" do
        let(:emit) do
          driver.run do
            driver.emit({'message' => '1', 'eventType' => 'foo'}, time.to_i)
            driver.emit({'message' => '2', 'eventType' => 'foo'}, time.to_i)
          end
        end
        let(:config) {%[
          tag tag
          enable_ruby #{enable_ruby}
          message bar ${message}
          eventtype ${eventType}
          remove_keys eventType
        ]}
        let(:tag) { 'prefix.test.tag.suffix' }
        let(:tag_parts) { tag.split('.') }
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, { 'message' => "bar 1", 'eventtype' => 'foo'})
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, { 'message' => "bar 2", 'eventtype' => 'foo'})
        end
        it { emit }
      end
    end
  end
end
