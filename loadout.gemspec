# frozen_string_literal: true

require_relative 'lib/loadout/version'

Gem::Specification.new do |spec|
  spec.name = 'loadout'
  spec.version = Loadout::VERSION
  spec.authors = ['Max Chernyak']
  spec.email = ['hello@max.engineer']

  spec.summary = 'Rails configuration helpers'
  spec.description = 'A few helpers to make vanilla Rails configuration neater.'
  spec.homepage = 'https://github.com/maxim/loadout'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[bin/ test/ .git .github Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
