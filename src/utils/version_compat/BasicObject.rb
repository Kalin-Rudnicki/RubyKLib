
# puts("RubyVersion: #{RUBY_VERSION}")

unless defined?(BasicObject)

	$stderr.puts("BasicObject will not behave properly in this version. (#{RUBY_VERSION})")
	
	class BasicObject
		
		# TODO => Make this behave like a normal BasicObject
		
	end

end
