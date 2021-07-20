# XXX: Knapsack rake tasks interroate RSpec::Core::Version before it might be
# loaded, so add a require first.
task 'knapsack_pro:rspec:version' do
  require 'rspec/core/version'
end

task 'knapsack_pro:rspec' => 'knapsack_pro:rspec:version'
