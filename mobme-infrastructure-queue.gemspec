
Gem::Specification.new do |s|
  s.name        = "mobme-infrastructure-queue"
  s.version     = "0.9.3"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Vishnu Gopal"]
  s.email       = ["vishnu@mobme.in"]
  s.homepage    = "http://www.mobme.in/"
  s.summary     = "A simple proxy to various queues"
  s.description = "Queue is a proxy to several queueing libraries: a homegrown queue on top of Redis, an in-process memory queue, an experimental zeromq backend and AMQP"
 
  s.required_rubygems_version = ">= 1.3.6"
 
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "flog"
  s.add_development_dependency "yard"
  s.add_development_dependency "ci_reporter"
  s.add_development_dependency "simplecov-rcov"
  s.add_development_dependency "diff-lcs"
  s.add_development_dependency "rdiscount"
  
  s.add_development_dependency "hiredis", "~> 0.3.1"
  s.add_development_dependency "redis", "~> 2.2.0"
  s.add_development_dependency "algorithms"
  s.add_development_dependency "em-synchrony"
  s.add_development_dependency "em-zeromq"
  s.add_development_dependency "bunny", "~> 0.7.4"
  
  s.add_dependency "yajl-ruby"
 
  s.files = Dir.glob("{lib,examples,bin}/**/*") + %w(README.md TODO.md)
  s.require_path = 'lib'
end
