
class Object

	class << self
		
		alias :__original_methods :methods
		def methods(mode = true)
			if mode == true || mode == false
				self.__original_methods(mode)
			elsif mode.is_a?(Class)
				mets = []
				klass = mode
				loop do
					if klass.nil?
						raise "[#{self}] does not inherit [#{mode}]"
					elsif klass == mode
						break
					else
						mets |= klass.__original_methods(false)
					end
					klass = klass.superclass
				end
				mets
			else
				raise ArgumentError.new("No explicit conversion of parameter 'mode' (#{mode.class.inspect}) to one of [TrueClass, FalseClass, Class]")
			end
		end
		
		alias :__original_instance_methods :instance_methods
		def instance_methods(mode = true)
			if mode == true || mode == false
				self.__original_instance_methods(mode)
			elsif mode.is_a?(Class)
				mets = []
				klass = self
				loop do
					if klass.nil?
						raise "[#{self}] does not inherit [#{mode}]"
					elsif klass == mode
						break
					else
						mets |= klass.__original_instance_methods(false)
					end
					klass = klass.superclass
				end
				mets
			else
				raise ArgumentError.new("No explicit conversion of parameter 'mode' (#{mode.class.inspect}) to one of [TrueClass, FalseClass, Class]")
			end
		end
	
	end

end

class Class
	
	alias :__original_superclass :superclass
	def superclass(before = nil)
		if before.nil?
			self.__original_superclass
		elsif before.is_a?(Class)
			klass = self
			loop do
				if klass.__original_superclass.nil?
					raise "[#{self}] does not inherit [#{before}]"
				elsif klass.__original_superclass == before
					return klass
				end
				klass = klass.__original_superclass
			end
		else
			raise ArgumentError.new("No explicit conversion of parameter 'before' to one of [NilClass, Class]")
		end
	end
	
end
