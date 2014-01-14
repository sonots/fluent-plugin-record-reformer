# encoding: UTF-8
require_relative 'spec_helper'

describe Fluent::RecordReformerOutput do
  before { Fluent::Test.setup }
  CONFIG = %[
    type reformed
    output_tag reformed.${tag}

    hostname ${hostname}
    tag ${tag}
    time ${time.strftime('%S')}
    message ${hostname} ${tag_parts.last} ${message}
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
      driver.run do
        driver.emit({'foo'=>'bar', 'message' => 1}, time.to_i)
        driver.emit({'foo'=>'bar', 'message' => 2}, time.to_i)
      end
    end

    context 'typical usage' do
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

    context 'support old ${tags} placeholder' do
      let(:config) { %[
        type reformed
        output_tag reformed.${tag}

        message ${tags[1]}
      ]}

      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).twice.with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'message' => "#{tag_parts[1]}",
        })
      end
      it { emit }
    end

    context 'record directive' do
      let(:config) {%[
        type reformed
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
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'foo' => 'bar',
          'hostname' => hostname,
          'output_tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 2",
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
        Fluent::Engine.should_receive(:emit).with("reformed.#{tag}", time.to_i, {
          'hostname' => hostname,
          'tag' => tag,
          'time' => time.strftime('%S'),
          'message' => "#{hostname} #{tag_parts.last} 2",
        })
      end
      it { emit }
    end
  end
end
