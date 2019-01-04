
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/validation/HashNormalizer'
	
	require 'test/unit'
end

def run_test(source, settings = {}, &block)
	begin
		2.times { puts }
		puts("Testing: #{source.inspect}")
		output = KLib::HashNormalizer.normalize_to({}, source, settings, &block)
		puts("Output: #{output.inspect}")
	rescue => e
		puts("<===== [ERROR] =====>")
		puts(e.class.inspect)
		puts(e.message)
		puts
		e.backtrace.each { |t| puts(t) }
	end
end

proc_1 = proc do |norm|

	norm.first_name(:first).required.type_check(String)
	norm.last_name(:last).required.type_check(String)
	
	norm.name.default_from_key(:first_name).type_check(String)
	
	norm.age.required.type_check(Integer)
	
	norm.favorite_color(:fav_color, :color).default_value(nil).type_check(NilClass, Symbol)

end

hash_1 = { :first_name => 'Kalin', :last_name => 'Rudnicki', :name => 'Best Programmer', :age => 20 }
hash_2 = { :first_name => 'Kalin', :last_name => 'Rudnicki', :age => 20 }

run_test(hash_1, &proc_1)
run_test(hash_2, &proc_1)
