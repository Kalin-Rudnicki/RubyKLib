
require 'set'
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/HashNormalizer'
end

class Array

	def duplicates(&block)
		dups = Set.new
		seen = Set.new
		arr = block_given? ? self.map { |e| block.call(e) } : self
		arr.each do |element|
			dups << element if seen.include?(element)
			seen << element
		end
		dups.to_a
	end
	
	def map_to_h(hash_args = {}, &block)
		raise ArgumentError.new("You must supply a block to this method") unless block_given?
		hash_args = KLib::HashNormalizer.normalize(hash_args) do |norm|
			norm.mode.default_value(:value).enum_check(:key, :value, :array)
		end
		case hash_args[:mode]
			when :key
				self.map { |e| [e, block.call(e)] }.to_h
			when :value
				self.map { |e| [block.call(e), e] }.to_h
			when :array
				self.map { |e| block.call(e) }.to_h
			else
				raise 'what is happening...'
		end
	end

end
