source "http://gems.mobme.in"
source :rubygems

group :development do
  gem "rake"
  gem "rspec"
  gem "guard"
  gem "guard-rspec"
  gem "simplecov"
  gem "flog"
  gem "yard"
  gem "ci_reporter"
  gem "simplecov-rcov"
  gem "diff-lcs"
  gem "rdiscount"
	gem "active_support"
end

group :osx do
  gem "growl"
  gem 'rb-fsevent'
end

group :linux do
  gem "rb-inotify"
  gem "libnotify"
end

gem "hiredis", "~> 0.3.1"
gem "redis", "~> 2.2.0", :require => ["redis/connection/hiredis", "redis"]
gem "yajl-ruby"
gem "algorithms"
gem 'em-synchrony'
gem 'em-zeromq'
