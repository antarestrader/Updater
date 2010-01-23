require 'rubygems'
require 'rake/gempackagetask'
require 'spec/rake/spectask'

VERSION_FILE = File.join(File.dirname(__FILE__), 'VERSION')

GEM_NAME = "updater"
GEM_VERSION = File.read(VERSION_FILE).strip
AUTHOR = "John F. Miller"
EMAIL = "emperor@antarestrader.com"
HOMEPAGE = "http://blog.antarestrader.com"
SUMMARY = "Plugin for the delayed calling of methods particularly DataMapper model instance and class methods."

spec = Gem::Specification.new do |s|
  s.name = GEM_NAME
  s.version = GEM_VERSION
  s.date = File.ctime(VERSION_FILE)
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "LICENSE", "VERSION"]
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.add_dependency('datamapper', '>= 0.9.11')
  s.add_development_dependency('rspec', '>= 1.2.6')
  s.add_development_dependency('timecop', '>= 0.2.1')
  s.add_development_dependency('chronic', '>= 0.2.3')
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.files = %w(LICENSE README Rakefile VERSION) + Dir.glob("{lib,spec,bin}/**/*")
  
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

Spec::Rake::SpecTask.new do |t|
  t.warning = false
  t.rcov = false
end

Spec::Rake::SpecTask.new do |t|
  t.name="failing"
  #todo Make this run only failing specs
  t.warning = false
  t.rcov = false
end

Spec::Rake::SpecTask.new do |t|
  t.name="rcov"
  t.warning = false
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