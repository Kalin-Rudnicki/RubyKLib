
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod

	def self.main(first_name, last_name, age)
	
	end
	
	def self.yatch(a)
	
	end
	
	module Main
		extend KLib::CliMod
	end
	
	module YaMan
		extend KLib::CliMod
	end
	
	module Yass
		extend KLib::CliMod
	end
	
end

Test.parse(%w{ya-m --test ok --why -abc -AF})
