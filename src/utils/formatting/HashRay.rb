
module HashRay

	INDENT = '|   '
	INSERT = '|-> '

end

class Object
	
	def hashray_to_s
		if self.instance_variables.any?
			str = "<#{self.class.inspect}>"
			self.instance_variables.sort.each do |var|
				str << "\n#{HashRay::INSERT}#{var} => " << self.instance_variable_get(var).hashray_to_s.gsub("\n", "\n#{HashRay::INDENT}")
			end
			str
		else
			self.to_s.gsub("\n", "\n#{HashRay::INDENT}")
		end
	end

end

class Symbol
	
	alias :hashray_to_s :inspect
	
end

def getKlass(hash)
	klass = Class.new
	inst = klass.new
	hash.each_pair { |k, v| inst.instance_variable_set(k, v) }
	inst
end

puts getKlass(:@a => 'a', :@b => :b, :@d => 3, :@c => "hi\nkalin").hashray_to_s
