
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/CliMod'
end

module Test
	extend KLib::CliMod
	
	def self.booleans_1(is_cool, can_code, dont_kill, wont_drive)
		puts("Called 'booleans':")
		puts("    is_cool:    #{is_cool.inspect}")
		puts("    can_code:   #{can_code.inspect}")
		puts("    dont_kill:  #{dont_kill.inspect}")
		puts("    wont_drive: #{wont_drive.inspect}")
	end
	
	def self.badgers
	
	end
	
	def self.types(arg_arr, my_hash)
		puts("Called 'types':")
		puts("    arg_arr:")
		arg_arr.each { |a| puts("    - #{a.inspect}") }
		puts("    my_hash:")
		my_hash.each_pair { |k, v| puts("    - #{k.inspect} => #{v.inspect}") }
	end
	
	
	method_spec(:hash) do |spec|
		spec.hash(:my_hash).data(:normalize => proc do |norm|
			norm.key_1.required.type_check(Float)
			norm.key_2.default_value(nil).enum_check(nil, :a, :b, :c)
			norm.key_3.default_value([]).type_check_each(Integer, Float)
		end)
	end
	
	def self.hash(my_hash)
		puts("    my_hash:")
		my_hash.each_pair { |k, v| puts("    - #{k.inspect} => #{v.inspect}") }
	end
	
end

Test.parse

#
#  Help Messages
# ---------------
#
# > CliModTests -h
# > CliModTests --help
# > CliModTests -H
# > CliModTests --help-extra
#
#
#  Help Messages (methods)
# -------------------------
#
# > CliModTests booleans-1 -h
# > CliModTests booleans-1 -H
#
# > CliModTests b-1 -h
# # 'b-1' autocompletes to 'booleans_1'
# > CliModTests b
# # 'b' cant complete because of 'badgers'
#
#
#  Fail on purpose
# -----------------
#
# CliModTests b-1
# CliModTests b-1 -f
# CliModTests b-1 --fail
#
#  Call the method successfully
# ------------------------------
#
# > CliModTests b-1 --is-cool --can-code --dont-kill --wont-drive
#
# # Notice how without any help, it figured out they were all booleans,
# # and notice how it automatically flips the values for negative names
#
#
#  Calling arrays and hashes
# ---------------------------
#
# # Arrays and hashes have their values automatically converted to the type they look like
# # (looks like int) => integer
# # (looks like float) => float
# # [arr] => ['arr'] (can not nest arrays (yet))
# # [arr, :arr, 5, 1.000, '7'] => ['arr', :arr, 5, 1.0, '7']
# # :sym => sym
# # 'str' => string
# # otherwise => string
#
# # Another thing to note, this parser does not follow the paradigm of -a 1,2,3 -a 4,5,6
# # you would do -a 1 2 3 4 5 6
#
# # Hashes are similar, make sure you put quotes around a hash call, or it will send your output to a file
#
# # "key=>value" => { :key => 'value' }
# # "'key'=>:value" => { 'key' => :value }
# # "5=>[1,4.00,    :sym]" => { 5 => [1, 4.0, :sym] }
#
# # A lot about the types of an argument can be assumed from its name
# # but if you want to do non-required arguments or validation,
# # you will need to specify a method_spec
#
# # with this, you can even leverage the full power of my HashNormalizer off of
# # arguments parsed from the command line
#
# # Try it by calling:
# > CliModTests hash -m ...
#
# # A few examples to try:
#
# > CliModTests hash -m
# > CliModTests hash -m "key_1=>this works?"
# > CliModTests hash -m "key_1=>5.0"
#
# > CliModTests hash -m "key_1=>5.0" "'key_2'=>a"
# > CliModTests hash -m "key_1=>5.0" "'key_2'=>:a"
#
# > CliModTests hash -m "key_1=>5.0" "'key_2'=>:a" "key_3=>5"
# > CliModTests hash -m "key_1=>5.0" "'key_2'=>:a" "key_3=>['5']"
# > CliModTests hash -m "key_1=>5.0" "'key_2'=>:a" "key_3=>[5]"
#
