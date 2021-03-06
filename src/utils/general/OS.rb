
module KLib

	module OS
	
		@platform = (/mingw/.match?(RUBY_PLATFORM) ? :windows : :unix)
		
		def self.windows?
			@platform == :windows
		end
		
		def self.unix?
			!windows?
		end
	
	end

end
