
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod
	
	def self.method_1
	
	end
	
	def self.method_2
	
	end
	
	def self.main
	
	end
	
	module SubMod
		extend KLib::CliMod
		
		def self.method_1
		
		end
		
		def self.method_2
		
		end
		
	end
	
end

Test.parse
