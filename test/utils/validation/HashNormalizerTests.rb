
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/validation/HashNormalizer'
	
	# require 'set'
	# require 'test/unit'
end

KLib::HashNormalizer.normalize({}, {}, :a => 0) do |norm|

	norm.a
	
	norm.puts(:as, :ok)

end
