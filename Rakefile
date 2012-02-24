require 'rspec/core/rake_task'
require "rake/tasklib"
require "flog"
require 'ci/reporter/rake/rspec'
require 'yard'
require 'yard/rake/yardoc_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

task :default => :spec

desc "Analyze for code complexity"
task :flog do
  flog = Flog.new
  flog.flog [ "lib" ]
  threshold = 10

  bad_methods = flog.totals.select do | name, score |
    name != "main#none" && score > threshold
  end
  bad_methods.sort do | a, b |
    a[ 1 ] <=> b[ 1 ]
  end.reverse.each do | name, score |
    puts "%8.1f: %s" % [ score, name ]
  end
  unless bad_methods.empty?
    raise "#{ bad_methods.size } methods have a flog complexity > #{ threshold }"
  end
end
