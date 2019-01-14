
class String
	
	def to_snake
		self.gsub(/::/, '/').
			gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
			gsub(/([a-z\d])([A-Z])/,'\1_\2').
			tr("-", "_").
			downcase
	end
	
	def to_camel(downcase_first_char = true)
		raise ArgumentError.new("Parameter 'downcase_first_char' must be one of [true, false].") unless downcase_first_char == true || downcase_first_char == false
		split = self.split('_').each { |str| str[0] = str[0].upcase if str.length > 0 }
		split[0][0] = split[0][0].downcase if downcase_first_char && split.length > 0 && split[0].length > 0
		split.join('')
	end

end
