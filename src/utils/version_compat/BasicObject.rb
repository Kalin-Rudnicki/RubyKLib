
puts("RubyVersion: #{RUBY_VERSION}")

class << $stderr
	
	def write(*args)
		args.each { |arg| $stdout.write(arg) }
	end

end

unless defined?(BasicObject)

	class BasicObject
		
		begin
			self.instance_methods.map { |m| m.to_sym }.each do |method|
				#puts("Attempting => #{method.inspect}")
				unless [:'!', :'!=', :'==', :'__id__', :'__send__', :'equal?', :'instance_eval', :'instance_exec'].include?(method)
					self.__send__(:remove_method, method)
					#puts("REMOVED!")
				end
			end
		rescue => e
			puts("[ERROR] #{e.class.inspect} => #{e.message}")
		end
		
	end

end

puts BasicObject.instance_methods.sort.inspect

class Klass < BasicObject
	
	def method_missing?(sym, *args)
		::Kernel::puts("#{sym}(#{args.join(', ')})")
	end
	
end

#:a.puts("hello_1")

BasicObject.new.puts("hello_2")


