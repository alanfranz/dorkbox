
VERSION = File.open(File.join(File.expand_path(File.dirname(__FILE__)), 'version.txt')).read().strip()

Gem::Specification.new do |s|
  s.name        = 'dorkbox'
  s.version     = VERSION
  s.date        = '2015-05-25'
  s.summary     = "dorkbox: dead simple personal file syncing"
  s.description = "dead simple personal file syncing"
  s.authors     = ["Alan Franzoni"]
  s.email       = 'username@franzoni.eu'
  s.files       = ["lib/dorkbox.rb", "lib/dorkbox_test.rb", "lib/bashlike.rb"]
  s.homepage    =
    'https://github.com/alanfranz/dorkbox'
  s.license     = 'Apache-2.0'
  s.bindir = 'executables'
  s.executables = ['dorkbox', 'test']
  s.add_runtime_dependency 'thor', '~> 0.19.1'
end
