# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{updater}
  s.version = "0.10.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John F. Miller"]
  s.date = %q{2011-03-06}
  s.default_executable = %q{updater}
  s.description = %q{A job queue which is ORM Agnostic and has advanced Error Handling}
  s.email = %q{emperor@antarestrader.com}
  s.executables = ["updater"]
  s.extra_rdoc_files = ["README.markdown", "LICENSE", "VERSION"]
  s.files = ["LICENSE", "README.markdown", "Rakefile", "VERSION", "lib/updater.rb", "lib/updater", "lib/updater/setup.rb", "lib/updater/util.rb", "lib/updater/update.rb", "lib/updater/fork_worker.rb", "lib/updater/tasks.rb", "lib/updater/thread_worker.rb", "lib/updater/orm", "lib/updater/orm/orm.rb", "lib/updater/orm/datamapper.rb", "lib/updater/orm/mock.rb", "lib/updater/orm/activerocord.rb", "lib/updater/orm/mongo.rb", "spec/results.html", "spec/datamapper_orm_spec.rb", "spec/fork_worker_instance_spec.rb", "spec/thread_worker_spec.rb", "spec/schedule_spec.rb", "spec/mock_orm_spec.rb", "spec/params_sub_spec.rb", "spec/chained_spec.rb", "spec/fooclass_spec.rb", "spec/fooclass.rb", "spec/update_spec.rb", "spec/mongo_orm_spec.rb", "spec/orm_lint.rb", "spec/spec_helper.rb", "spec/named_request_spec.rb", "spec/update_runner_spec.rb", "spec/util_spec.rb", "spec/fork_worker_spec.rb", "spec/errors_spec.rb", "bin/updater"]
  s.homepage = %q{http://github.com/antarestrader/Updater}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{A job queue which is ORM Agnostic and has advanced Error Handling}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<datamapper>, [">= 0.10.2"])
      s.add_development_dependency(%q<rspec>, [">= 2.0.0"])
      s.add_development_dependency(%q<timecop>, [">= 0.2.1"])
      s.add_development_dependency(%q<chronic>, [">= 0.2.3"])
    else
      s.add_dependency(%q<datamapper>, [">= 0.10.2"])
      s.add_dependency(%q<rspec>, [">= 2.0.0"])
      s.add_dependency(%q<timecop>, [">= 0.2.1"])
      s.add_dependency(%q<chronic>, [">= 0.2.3"])
    end
  else
    s.add_dependency(%q<datamapper>, [">= 0.10.2"])
    s.add_dependency(%q<rspec>, [">= 2.0.0"])
    s.add_dependency(%q<timecop>, [">= 0.2.1"])
    s.add_dependency(%q<chronic>, [">= 0.2.3"])
  end
end
