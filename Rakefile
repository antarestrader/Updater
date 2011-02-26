require 'rubygems'
require 'rake/gempackagetask'
require 'rspec/core/rake_task'


VERSION_FILE = File.join(File.dirname(__FILE__), 'VERSION')

GEM_NAME = "updater"
GEM_VERSION = File.read(VERSION_FILE).strip
AUTHOR = "John F. Miller"
EMAIL = "emperor@antarestrader.com"
HOMEPAGE = "http://github.com/antarestrader/Updater"
SUMMARY = "A job queue which is ORM Agnostic and has advanced Error Handling"

spec = Gem::Specification.new do |s|
  s.name = GEM_NAME
  s.version = GEM_VERSION
  s.date = File.ctime(VERSION_FILE)
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.markdown", "LICENSE", "VERSION"]
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.add_development_dependency('datamapper', '>= 0.10.2')
  s.add_development_dependency('rspec', '>= 2.0.0')
  s.add_development_dependency('timecop', '>= 0.2.1')
  s.add_development_dependency('chronic', '>= 0.2.3')
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.executables = 'updater'
  s.files = %w(LICENSE README.markdown Rakefile VERSION) + Dir.glob("{lib,spec,bin}/**/*")
  
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

RSpec::Core::RakeTask.new do |t|
  ruby_opts="-w"
  t.rcov = false
end

RSpec::Core::RakeTask.new do |t|
  t.name="failing"
  #todo Make this run only failing specs
  ruby_opts="-w"
  t.rcov = false
end

RSpec::Core::RakeTask.new do |t|
  t.name="rcov"
  ruby_opts="-w"
  t.rcov = true
end

desc "run all tests"
task :default => [:spec]

desc "Create a gemspec file"
task :gemspec do
  File.open("#{GEM_NAME}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end