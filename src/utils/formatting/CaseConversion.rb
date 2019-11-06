
require_relative '../validation/ArgumentChecking'

class String
	
	def to_snake
		self.gsub(/::/, '/').
			gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
			gsub(/([a-z])(\d)/,'\1_\2').
			gsub(/([a-z\d])([A-Z])/,'\1_\2').
			tr("-", "_").
			downcase
	end
	
	def to_camel(downcase_first_char = true)
		KLib::ArgumentChecking.type_check(downcase_first_char, :downcase_first_char, Boolean)
		split = self.split('_').each { |str| str[0] = str[0].upcase if str.length > 0 }
		split[0][0] = split[0][0].downcase if downcase_first_char && split.length > 0 && split[0].length > 0
		split.join('')
	end

end
