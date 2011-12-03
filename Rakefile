require 'rspec/core/rake_task'
require "rake/tasklib"
require "flog"
require 'ci/reporter/rake/rspec'

RSpec::Core::RakeTask.new(:spec => ["ci:setup:rspec"]) do |t|
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

namespace :gem do
  task :push do
    puts "Building gem from gemspec..."
    system("gem build *.gemspec")
    puts "Pushing up gem to gems.mobme.in..."
    system("scp -P 2200 *.gem mobme@gems.mobme.in:/home/mobme/public_html/gems.mobme.in/gems")
    puts "Rebuilding index..."
    system('ssh mobme@gems.mobme.in -p 2200 "cd /home/mobme/public_html/gems.mobme.in && /usr/local/rvm/bin/rvm 1.9.2 do gem generate_index"')
    puts "Done"
  end
end
