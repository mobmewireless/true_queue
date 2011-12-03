
Gem::Specification.new do |s|
  s.name        = "mobme-infrastructure-redis-queue"
  s.version     = "0.9"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Vishnu Gopal"]
  s.email       = ["vishnu@mobme.in"]
  s.homepage    = "http://www.mobme.in/"
  s.summary     = "A simple but complete queueing system built on top of Redis"
  s.description = "Redis Queue is a simple (under 200sloc) but complete queueing system built on top of Redis. It can both schedule and prioritise queued items."
 
  s.required_rubygems_version = ">= 1.3.6"
 
  s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "rdiscount"

  s.add_dependency "yajl-ruby"
  s.add_dependency "hi-redis"
  s.add_dependency "redis", ">= 2.2"
 
  s.files = Dir.glob("{lib,examples,bin}/**/*") + %w(README.md TODO.md)
  s.require_path = 'lib'
end
