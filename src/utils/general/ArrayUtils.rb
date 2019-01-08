
require 'set'

class Array

	def duplicates(&block)
		dups = Set.new
		seen = Set.new
		if block_given?
			self.each do |element|
				dups << element if seen.include?(block.call(element))
				seen << element
			end
		else
			self.each do |element|
				dups << element if seen.include?(element)
				seen << element
			end
		end
		dups.to_a
	end

end
