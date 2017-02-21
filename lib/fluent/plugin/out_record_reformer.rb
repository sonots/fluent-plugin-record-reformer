require 'fluent/version'
major, minor, patch = Fluent::VERSION.split('.').map(&:to_i)
if major > 0 || (major == 0 && minor >= 14)
  require_relative 'out_record_reformer/v14'
else
  require_relative 'out_record_reformer/v12'
end
