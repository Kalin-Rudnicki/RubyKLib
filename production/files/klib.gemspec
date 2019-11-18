
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "klib/version"

Gem::Specification.new do |spec|
  spec.name          = "klib"
  spec.version       = KLib::VERSION
  spec.authors       = ["Kalin-Rudnicki"]
  spec.email         = ["deaddorks@gmail.com"]

  spec.summary       = %q{Some useful ruby utilities}
  spec.homepage      = "https://github.com/Kalin-Rudnicki/RubyKLib/tree/master/src"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
	  files = Dir.glob('./**/*').select { |f| File.file?(f) }
	  files << './lib/'
	  # puts files
	  files
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
