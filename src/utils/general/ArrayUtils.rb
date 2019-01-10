
require 'set'

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

end
