
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod
	
	def self.method_1(my_favorite_variable_name_of_all_time)
	
	end
	
	method_spec(:method_2) do |spec|
		spec.string(:first_name).comments('Your first name')
		spec.string(:last_name).comments('Your first name')
		spec.string(:age).comments('Your age,', 'must be an integer')
		spec.string(:favorite_food).comments('Your favorite food')
		spec.boolean(:is_awesome).default_value(false)
	end
	
	def self.method_2(first_name, last_name, age, favorite_food, is_awesome, dont_kill, can_code)
	
	end
	
	def self.main
	
	end
	
	module SubMod
		extend KLib::CliMod
		
		def self.method_1(can_code, cant_walk)
			puts("can_code: #{can_code.inspect}")
			puts("cant_walk: #{cant_walk.inspect}")
		end
		
		def self.method_2
		
		end
		
	end
	
end

Test.parse
