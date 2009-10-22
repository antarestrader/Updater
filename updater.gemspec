# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{updater}
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John F. Miller"]
  s.date = %q{2009-10-21}
  s.description = %q{Plugin for the delayed calling of methods particularly DataMapper model instance and class methods.}
  s.email = %q{emperor@antarestrader.com}
  s.extra_rdoc_files = ["README", "LICENSE", "VERSION"]
  s.files = ["LICENSE", "README", "Rakefile", "VERSION", "lib/updater.rb", "lib/updater", "lib/updater/update.rb", "lib/updater/tasks.rb", "lib/updater/worker.rb", "spec/worker_spec.rb", "spec/lock_spec.rb", "spec/update_spec.rb", "spec/spec_helper.rb", "bin/updater"]
  s.homepage = %q{http://blog.antarestrader.com}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Plugin for the delayed calling of methods particularly DataMapper model instance and class methods.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<datamapper>, [">= 0.9.11"])
      s.add_development_dependency(%q<rspec>, [">= 1.2.6"])
      s.add_development_dependency(%q<timecop>, [">= 0.2.1"])
      s.add_development_dependency(%q<chronic>, [">= 0.2.3"])
    else
      s.add_dependency(%q<datamapper>, [">= 0.9.11"])
      s.add_dependency(%q<rspec>, [">= 1.2.6"])
      s.add_dependency(%q<timecop>, [">= 0.2.1"])
      s.add_dependency(%q<chronic>, [">= 0.2.3"])
    end
  else
    s.add_dependency(%q<datamapper>, [">= 0.9.11"])
    s.add_dependency(%q<rspec>, [">= 1.2.6"])
    s.add_dependency(%q<timecop>, [">= 0.2.1"])
    s.add_dependency(%q<chronic>, [">= 0.2.3"])
  end
end
