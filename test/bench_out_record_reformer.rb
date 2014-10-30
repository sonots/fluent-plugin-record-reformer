# encoding: UTF-8
require_relative 'helper'
require 'fluent/plugin/out_record_reformer'
require 'benchmark'
Fluent::Test.setup

def create_driver(config, tag = 'foo.bar')
  Fluent::Test::OutputTestDriver.new(Fluent::RecordReformerOutput, tag).configure(config)
end

# setup
message = {'message' => "2013/01/13T07:02:11.124202 INFO GET /ping"}
time = Time.now.to_i

enable_ruby_driver = create_driver(%[
  enable_ruby true
  output_tag reformed.${tag}
  message ${tag_parts[0]}
])
disable_ruby_driver = create_driver(%[
  enable_ruby false
  output_tag reformed.${tag}
  message ${tag_parts[0]}
])

# bench
n = 1000
Benchmark.bm(7) do |x|
  x.report("enable_ruby")  { enable_ruby_driver.run  { n.times { enable_ruby_driver.emit(message, time)  } } }
  x.report("disable_ruby") { disable_ruby_driver.run { n.times { disable_ruby_driver.emit(message, time) } } }
end

#BEFORE REFACTORING
#              user     system      total        real
#enable_ruby  0.310000   0.000000   0.310000 (  0.835560)
#disable_ruby  0.150000   0.000000   0.150000 (  0.679239)

#AFTER REFACTORING (PlaceholderParser and RubyPlaceholderParser)
#              user     system      total        real
#enable_ruby  0.290000   0.010000   0.300000 (  0.815281)
#disable_ruby  0.060000   0.000000   0.060000 (  0.588556)
