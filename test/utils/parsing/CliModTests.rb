
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod

	method_spec(:main) do |spec|
		spec.param(:first_name)
		spec.param(:dont_kill).boolean_data(:mode => :do_dont, :flip => true)
	end
	
	def self.main(first_name, last_name, age, is_cool, dont_kill)
	
	end
	
end

$stderr = $stdout
Test.parse(%w{main --first-name})
