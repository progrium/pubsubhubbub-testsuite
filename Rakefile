require 'rubygems'
require 'spec/rake/spectask'

task :default => [:all]

opts = ['--format', 'specdoc', '-c']

desc "Run all specs"
Spec::Rake::SpecTask.new(:all) do |t|
  t.spec_files = FileList["hub_*_spec.rb"]
  t.spec_opts = opts
end

desc "Run all core (MUST) specs"
Spec::Rake::SpecTask.new(:core) do |t|
  t.spec_files = FileList["hub_*_must_spec.rb"]
  t.spec_opts = opts
end

desc "Run all secondary (SHOULD) specs"
Spec::Rake::SpecTask.new(:secondary) do |t|
  t.spec_files = FileList["hub_*_should_spec.rb"]
  t.spec_opts = opts
end

desc "Run specs for optional features"
Spec::Rake::SpecTask.new(:optional) do |t|
  t.spec_files = FileList["hub_*_optional_spec.rb"]
  t.spec_opts = opts
end

desc "Run specs acting as a subscriber"
Spec::Rake::SpecTask.new(:subscriber) do |t|
  t.spec_files = FileList["hub_subscriber_*_spec.rb"]
  t.spec_opts = opts
end

desc "Run specs acting as a publisher"
Spec::Rake::SpecTask.new(:publisher) do |t|
  t.spec_files = FileList["hub_publisher_*_spec.rb"]
  t.spec_opts = opts
end
