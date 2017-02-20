require 'fluent/version'
major, minor, patch = Fluent::VERSION.split('.')
if major.to_i > 0 || minor.to_i >= 14
  require_relative 'out_record_reformer/v14'
else
  require_relative 'out_record_reformer/v12'
end
