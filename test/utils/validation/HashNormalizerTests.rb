
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/validation/HashNormalizer'
	
	# require 'set'
	# require 'test/unit'
end

KLib::HashNormalizer.normalize({}, {}) do |norm|

	norm.a
	
	norm.puts(:as, :ok)

end
