# encoding: UTF-8
require_relative 'spec_helper'

describe Fluent::RecordReformerOutput do
  before { Fluent::Test.setup }
  CONFIG = %[
    type reformed
    output_tag reformed

    hostname ${hostname}
    tag ${tag}
    time ${time.strftime('%S')}
    message ${hostname} ${tags.last} ${message}
  ]
  let(:tag) { 'test.tag' }
  let(:tags) { tag.split('.') }
  let(:hostname) { Socket.gethostname.chomp }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::RecordReformerOutput, tag).configure(config) }

  describe 'test configure' do
    describe 'good configuration' do
      subject { driver.instance }

      context "check default" do
        let(:config) { CONFIG }
        its(:output_tag) { should == 'reformed' }
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

    let(:config) { CONFIG }
    before do
      Fluent::Engine.stub(:now).and_return(time)
      Fluent::Engine.should_receive(:emit).with("reformed", time.to_i, {
        'foo' => 'bar',
        'hostname' => hostname,
        'tag' => tag,
        'time' => time.strftime('%S'),
        'message' => "#{hostname} #{tags.last} 1",
      })
      Fluent::Engine.should_receive(:emit).with("reformed", time.to_i, {
        'foo' => 'bar',
        'hostname' => hostname,
        'tag' => tag,
        'time' => time.strftime('%S'),
        'message' => "#{hostname} #{tags.last} 2",
      })
    end
    it { emit }
  end
end
