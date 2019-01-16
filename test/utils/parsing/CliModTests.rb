
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod

	method_spec(:main) do |spec|
		spec.int(:age)
	end
	
	def self.main(first_name, last_name, age)
		puts("first_name: #{first_name.inspect}")
		puts("last_name: #{last_name.inspect}")
		puts("age: #{age.inspect}")
		{ :first_name => first_name, :last_name => last_name, :age => age }
	end
	
end

$stderr = $stdout
puts Test.parse
