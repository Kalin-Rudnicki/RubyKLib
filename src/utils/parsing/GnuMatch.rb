
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/ArgumentChecking'
end

module KLib
	
	module GnuMatch
		
		def self.match(string, options)
			ArgumentChecking.type_check(string, 'string', String)
			ArgumentChecking.type_check_each(options, 'options', String)
			
			matches = []
			options.each do |opt|
				return opt if string == opt
				matches << opt if opt.start_with?(string)
			end
			
			matches.length == 1 ? matches.first : nil
		end
		
		def self.multi_match(string, options)
			ArgumentChecking.type_check(string, 'string', String)
			ArgumentChecking.type_check_each(options, 'options', String)
			
			string_split = string.split('_')
			options_split = options.map { |opt| [opt, opt.split('_')] }.to_h
			
			matches = []
			options_split.each_pair do |orig, split|
				return orig if split == orig
				if orig.start_with?(string)
					matches << orig
					next
				end
				next if string_split.length > split.length
				valid = true
				string_split.length.times do |idx|
					unless split[idx].start_with?(string_split[idx])
						valid = false
						break
					end
				end
				matches << orig if valid
			end
			
			matches.length == 1 ? matches.first : nil
		end
		
	end
	
end

