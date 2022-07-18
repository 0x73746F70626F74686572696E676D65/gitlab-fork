require_relative 'lib/bundler/checksum/version'

Gem::Specification.new do |spec|
  spec.name          = 'bundler-checksum'
  spec.version       = Bundler::Checksum::VERSION
  spec.authors       = ['dustinmm80']
  spec.email         = ['dcollins@gitlab.com']

  spec.summary       = 'Track checksums locally with Bundler'
  spec.description   = 'Track checksums locally with Bundler'
  spec.homepage      = 'https://gitlab.com/gitlab-org/distribution/bundle-checksum'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler', '~> 2.2'
  # spec.add_development_dependency 'rake', '~> 13.0'
  # spec.add_development_dependency 'minitest', '~> 5.0'
end
