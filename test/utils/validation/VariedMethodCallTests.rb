
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/validation/VariedMethodCall'
end

proc_1 = proc do |opts|
	
	opts.on(:args, Hash) { |args| [args[0..-2], args[-1]] }
	opts.on(Integer, Float, :args) { |args| [args[0], args[1], args[2..-1]] }
	opts.on(Float, Integer, :args) { |args| [args[0], args[1], args[2..-1]] }
	opts.on(Integer, :args) { |args| [args[0], nil, args[1..-1]] }
	opts.on(Float, :args) { |args| [nil, args[0], args[1..-1]] }
	opts.on(:args) { |args| [nil, nil, args] }

end

puts KLib::VariedMethodCall.parse([5], &proc_1).inspect
puts KLib::VariedMethodCall.parse([5.0, :'7'], &proc_1).inspect
puts KLib::VariedMethodCall.parse([:'7'], &proc_1).inspect
puts KLib::VariedMethodCall.parse([:'7', {:a => 1, :b => 2}], &proc_1).inspect
