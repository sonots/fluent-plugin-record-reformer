# encoding: UTF-8
require_relative 'spec_helper'

describe Fluent::RecordReformerOutput do
  before { Fluent::Test.setup }
  CONFIG = %[
    output_tag reformed.${tag}

    hostname ${hostname}
    tag ${tag}
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
          'tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 1",
        })
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'hostname' => hostname,
          'tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 2",
        })
      end
      it { emit }
    end

    context 'record directive' do
      let(:config) {%[
        output_tag reformed.${tag}

        <record>
          hostname ${hostname}
          output_tag ${tag}
          time ${time.strftime('%S')}
          message ${hostname} ${tag_parts.last} ${message}
        </record>
      ]}
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'hostname' => hostname,
          'output_tag' => tag,
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
          'tag' => tag,
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
          'tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 1",
        })
      end
      it { emit }
    end

    context 'unknown placeholder (enable_ruby no)' do
      let(:emit) do
        driver.run { driver.emit({}, time.to_i) }
      end
      let(:config) {%[
        output_tag reformed.${tag}
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
          output_tag tag
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
          output_tag tag
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
          output_tag tag
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
          output_tag tag
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
          output_tag ${tag_suffix[-2]}
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
          output_tag tag
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
            driver.emit({'message' => '1'}, time.to_i)
            driver.emit({'message' => '2'}, time.to_i)
          end
        end
        let(:config) {%[
          output_tag tag
          enable_ruby #{enable_ruby}
          message bar ${message}
        ]}
        let(:tag) { 'prefix.test.tag.suffix' }
        let(:tag_parts) { tag.split('.') }
        before do
          Fluent::Engine.stub(:now).and_return(time)
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, { 'message' => "bar 1", })
          Fluent::Engine.should_receive(:emit).with("tag", time.to_i, { 'message' => "bar 2", })
        end
        it { emit }
      end
    end
  end
end
