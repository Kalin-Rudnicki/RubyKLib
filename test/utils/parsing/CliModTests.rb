
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod

	method_spec(:main) do |spec|
		spec.float(:balance).data(:post => proc { |d| d > 5 })
		spec.hash(:transactions).data(:normalize => proc { |norm| norm.ok.required })
		spec.symbol(:type)
	end
	
	def self.main(account_holder, balance, type, transactions, test_path, dont_kill)
		puts("--- Local Variables ---")
		binding.local_variables.each do |loc|
			puts("#{"#{loc.inspect}".rjust(15)} => #{binding.local_variable_get(loc).inspect}")
		end
		
		nil
	end
	
	method_spec(:test) do |spec|
		spec.boolean(:is_a).data(:mode => :is_isnt, :flip => false)
		spec.boolean(:isnt_b).data(:mode => :is_isnt, :flip => true)
		spec.boolean(:c).data(:mode => :_isnt, :flip => false)
		spec.boolean(:isnt_d).data(:mode => :_isnt, :flip => true).default_value(true)
	end
	
	def self.test(is_a, isnt_b, c, isnt_d)
		puts("--- Local Variables ---")
		binding.local_variables.each do |loc|
			puts("#{"#{loc.inspect}".rjust(15)} => #{binding.local_variable_get(loc).inspect}")
		end
		
		nil
		
	end
	
	def self.other_2(a, b)
	
	end
	
	module Inner
		extend KLib::CliMod
		
		def self.main(a)
		
		end
		
	end
	
end

$stderr = $stdout
Test.parse
