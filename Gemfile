source "http://rubygems.org"

gem 'activerecord', ENV['ACTIVE_RECORD_VERSION']
gem "activesupport", ENV['ACTIVE_RECORD_VERSION']

group :development do
  gem "bundler", "~> 1.0.0"
  gem "jeweler", "~> 1.6.0"
end

group :test do
  gem 'sqlite3'
  version_str = if ENV['ACTIVE_RECORD_VERSION'] =~ /^3\./
    "~> 1.5.0"
  else
    "~> 1.4.0"
  end
  gem "validates_email_format_of", version_str
end
