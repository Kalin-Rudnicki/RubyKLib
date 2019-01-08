
require 'set'

class Array

	def duplicates
		dups = Set.new
		seen = Set.new
		self.each do |element|
			dups << element if seen.include?(element)
			seen << element
		end
		dups.to_a
	end

end
